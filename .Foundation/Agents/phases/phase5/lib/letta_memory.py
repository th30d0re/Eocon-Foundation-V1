#!/usr/bin/env python3
"""
Letta Memory Helper for Foundation Build Agents

Provides CLI interface for memory operations using Letta Learning-SDK.
Supports both Letta Cloud and self-hosted instances.

Environment Variables:
    LETTA_API_KEY     - API key for Letta authentication (required)
    LETTA_BASE_URL    - Optional: Self-hosted server URL
    LETTA_MODEL       - Optional: Default model for new agents

Exit Codes:
    0  - Success
    1  - General error
    2  - Configuration error (missing env vars or dependencies)
    3  - Agent not found
    4  - Memory block not found
    5  - API error
"""

import argparse
import json
import os
import sys
from typing import Optional, List, Dict, Any


def check_python_version():
    """Ensure Python 3.10+ is being used."""
    if sys.version_info < (3, 10):
        print(f"ERROR: Python 3.10+ required, got {sys.version}", file=sys.stderr)
        sys.exit(2)


def get_letta_client():
    """Initialize Letta client with environment configuration."""
    try:
        from agentic_learning import AgenticLearning
    except ImportError:
        print("ERROR: agentic_learning not installed", file=sys.stderr)
        print("Install with: pip install agentic-learning", file=sys.stderr)
        sys.exit(2)

    api_key = os.environ.get("LETTA_API_KEY")
    if not api_key:
        print("ERROR: LETTA_API_KEY environment variable not set", file=sys.stderr)
        print("Get your API key from: https://app.letta.com/api-keys", file=sys.stderr)
        sys.exit(2)

    base_url = os.environ.get("LETTA_BASE_URL")

    try:
        if base_url:
            return AgenticLearning(api_key=api_key, base_url=base_url)
        else:
            return AgenticLearning(api_key=api_key)
    except Exception as e:
        print(f"ERROR: Failed to initialize Letta client: {e}", file=sys.stderr)
        sys.exit(5)


class LettaMemoryHelper:
    """Helper class for Letta memory operations."""

    def __init__(self):
        self.client = None  # Lazy initialization

    def _get_client(self):
        """Get or create the Letta client."""
        if self.client is None:
            self.client = get_letta_client()
        return self.client

    def check_env(self) -> bool:
        """Check if environment is properly configured."""
        # Check Python version
        if sys.version_info < (3, 10):
            return False

        # Check for required packages
        try:
            import agentic_learning
        except ImportError:
            return False

        # Check for API key
        if not os.environ.get("LETTA_API_KEY"):
            return False

        return True

    def init_agent(self, agent_name: str, memory_blocks: List[str]) -> Dict[str, Any]:
        """Initialize or retrieve agent with specified memory blocks."""
        client = self._get_client()

        model = os.environ.get("LETTA_MODEL", "anthropic/claude-sonnet-4-20250514")

        try:
            # Try to create new agent
            agent = client.agents.create(
                agent=agent_name,
                memory=memory_blocks,
                model=model
            )
        except Exception as e:
            # Agent might already exist, try to retrieve
            try:
                agent = client.agents.retrieve(agent_name)
            except Exception:
                raise e

        return {
            "agent": agent_name,
            "memory_blocks": memory_blocks,
            "model": model,
            "status": "initialized"
        }

    def store_memory(self, agent_name: str, block_label: str, data: str) -> Dict[str, Any]:
        """Store data in a memory block (upsert - create or update)."""
        client = self._get_client()

        # Parse data as JSON if possible, otherwise treat as string
        try:
            parsed_data = json.loads(data)
            value = json.dumps(parsed_data, indent=2)
        except json.JSONDecodeError:
            value = data

        stored = False

        # Try create first (will fail if block exists)
        try:
            client.memory.create(
                agent=agent_name,
                label=block_label,
                value=value
            )
            stored = True
        except Exception as create_error:
            # Block likely exists, try to update via underlying letta client
            try:
                # Get the agent ID and block ID
                letta = client._letta
                agents = letta.agents.list()
                agent_id = None
                for a in agents:
                    if hasattr(a, 'name') and a.name == agent_name:
                        agent_id = a.id
                        break

                if agent_id:
                    # Get the block and update it
                    blocks = letta.agents.blocks.list(agent_id=agent_id)
                    for b in blocks:
                        if hasattr(b, 'label') and b.label == block_label:
                            letta.blocks.modify(
                                block_id=b.id,
                                value=value
                            )
                            stored = True
                            break
            except Exception:
                # Last resort: use remember to store as a memory entry
                try:
                    client.memory.remember(
                        agent=agent_name,
                        prompt=f"[{block_label}] {value}"
                    )
                    stored = True
                except Exception:
                    pass

        return {
            "agent": agent_name,
            "block": block_label,
            "status": "stored" if stored else "failed",
            "size": len(value)
        }

    def retrieve_memory(self, agent_name: str, block_label: str) -> str:
        """Retrieve data from a memory block."""
        client = self._get_client()

        try:
            # Try direct retrieval first
            result = client.memory.retrieve(
                agent=agent_name,
                label=block_label
            )
            if result:
                # BlockResponse object has a .value attribute
                if hasattr(result, 'value'):
                    return result.value or ""
                elif isinstance(result, dict):
                    return result.get("value", "")
                return str(result)
        except Exception:
            pass

        # Fallback to using underlying letta client
        try:
            letta = client._letta
            agents = letta.agents.list()
            for a in agents:
                if hasattr(a, 'name') and a.name == agent_name:
                    blocks = letta.agents.blocks.list(agent_id=a.id)
                    for b in blocks:
                        if hasattr(b, 'label') and b.label == block_label:
                            return b.value or ""
                    break
        except Exception:
            pass

        return ""

    def search_memory(self, agent_name: str, query: str, limit: int = 5) -> List[Dict[str, Any]]:
        """Semantic search across agent memory."""
        client = self._get_client()

        try:
            results = client.memory.search(
                agent=agent_name,
                prompt=query  # SDK uses 'prompt' not 'query'
            )
            if results:
                # Convert message objects to dicts
                output = []
                for r in results[:limit]:
                    if hasattr(r, 'content'):
                        output.append({"content": r.content, "type": getattr(r, 'message_type', 'unknown')})
                    elif isinstance(r, dict):
                        output.append(r)
                    else:
                        output.append({"content": str(r)})
                return output
            return []
        except Exception as e:
            print(f"WARNING: Search failed: {e}", file=sys.stderr)
            return []

    def list_blocks(self, agent_name: str) -> List[str]:
        """List all memory blocks for an agent."""
        client = self._get_client()

        try:
            # Use underlying letta client to list blocks
            letta = client._letta
            agents = letta.agents.list()
            for a in agents:
                if hasattr(a, 'name') and a.name == agent_name:
                    blocks = letta.agents.blocks.list(agent_id=a.id)
                    labels = []
                    for b in blocks:
                        if hasattr(b, 'label') and b.label:
                            labels.append(b.label)
                    return sorted(labels)
        except Exception:
            pass

        return []

    def remember(self, agent_name: str, content: str) -> Dict[str, Any]:
        """Store an explicit memory (for implicit learning)."""
        client = self._get_client()

        try:
            result = client.memory.remember(
                agent=agent_name,
                prompt=content  # SDK uses 'prompt' not 'content'
            )
            return {"status": "remembered", "content_length": len(content), "result": result}
        except Exception as e:
            return {"status": "error", "error": str(e)}

    def get_context(self, agent_name: str, query: str) -> str:
        """Get memory context for a query (for prompt injection)."""
        client = self._get_client()

        try:
            context = client.memory.context(
                agent=agent_name,
                query=query
            )
            return context if context else ""
        except Exception:
            return ""


def main():
    """Main CLI entry point."""
    check_python_version()

    parser = argparse.ArgumentParser(
        description="Letta Memory Helper for Foundation Build Agents",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Check environment
  %(prog)s check-env

  # Initialize agent with memory blocks
  %(prog)s init --agent my_project --memory "build_context,error_patterns,test_results"

  # Store data
  %(prog)s store --agent my_project --block build_context --data '{"scheme": "MyApp"}'

  # Retrieve data
  %(prog)s retrieve --agent my_project --block build_context

  # Semantic search
  %(prog)s search --agent my_project --query "error patterns for SwiftUI"

Environment Variables:
  LETTA_API_KEY     Required: API key from app.letta.com
  LETTA_BASE_URL    Optional: Self-hosted server URL
  LETTA_MODEL       Optional: Default model (default: claude-sonnet-4)
"""
    )

    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # check-env command
    subparsers.add_parser("check-env", help="Check environment configuration")

    # init command
    init_parser = subparsers.add_parser("init", help="Initialize agent with memory blocks")
    init_parser.add_argument("--agent", required=True, help="Agent name")
    init_parser.add_argument("--memory", required=True, help="Comma-separated memory blocks")

    # store command
    store_parser = subparsers.add_parser("store", help="Store data in memory block")
    store_parser.add_argument("--agent", required=True, help="Agent name")
    store_parser.add_argument("--block", required=True, help="Memory block name")
    store_parser.add_argument("--data", required=True, help="Data to store (JSON or string)")
    store_parser.add_argument("--file", help="Read data from file instead of --data")

    # retrieve command
    retrieve_parser = subparsers.add_parser("retrieve", help="Retrieve data from memory block")
    retrieve_parser.add_argument("--agent", required=True, help="Agent name")
    retrieve_parser.add_argument("--block", required=True, help="Memory block name")

    # search command
    search_parser = subparsers.add_parser("search", help="Semantic search in memory")
    search_parser.add_argument("--agent", required=True, help="Agent name")
    search_parser.add_argument("--query", required=True, help="Search query")
    search_parser.add_argument("--limit", type=int, default=5, help="Max results (default: 5)")

    # list-blocks command
    list_parser = subparsers.add_parser("list-blocks", help="List memory blocks")
    list_parser.add_argument("--agent", required=True, help="Agent name")

    # remember command (for implicit learning)
    remember_parser = subparsers.add_parser("remember", help="Store explicit memory for learning")
    remember_parser.add_argument("--agent", required=True, help="Agent name")
    remember_parser.add_argument("--content", required=True, help="Content to remember")

    # context command (for prompt injection)
    context_parser = subparsers.add_parser("context", help="Get memory context for query")
    context_parser.add_argument("--agent", required=True, help="Agent name")
    context_parser.add_argument("--query", required=True, help="Query to get context for")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    helper = LettaMemoryHelper()

    try:
        if args.command == "check-env":
            if helper.check_env():
                print("OK")
                sys.exit(0)
            else:
                # Provide specific feedback
                if sys.version_info < (3, 10):
                    print(f"PYTHON_VERSION_ERROR: Requires 3.10+, got {sys.version_info.major}.{sys.version_info.minor}")
                else:
                    try:
                        import agentic_learning
                        if not os.environ.get("LETTA_API_KEY"):
                            print("MISSING_API_KEY")
                        else:
                            print("UNKNOWN_ERROR")
                    except ImportError:
                        print("MISSING_PACKAGE")
                sys.exit(2)

        elif args.command == "init":
            memory_blocks = [b.strip() for b in args.memory.split(",")]
            result = helper.init_agent(args.agent, memory_blocks)
            print(json.dumps(result))

        elif args.command == "store":
            data = args.data
            if args.file:
                with open(args.file, 'r') as f:
                    data = f.read()
            result = helper.store_memory(args.agent, args.block, data)
            print(json.dumps(result))

        elif args.command == "retrieve":
            result = helper.retrieve_memory(args.agent, args.block)
            print(result)

        elif args.command == "search":
            results = helper.search_memory(args.agent, args.query, args.limit)
            print(json.dumps(results, indent=2))

        elif args.command == "list-blocks":
            blocks = helper.list_blocks(args.agent)
            print(json.dumps(blocks))

        elif args.command == "remember":
            result = helper.remember(args.agent, args.content)
            print(json.dumps(result))

        elif args.command == "context":
            result = helper.get_context(args.agent, args.query)
            print(result)

    except KeyboardInterrupt:
        print("\nInterrupted", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(5)


if __name__ == "__main__":
    main()

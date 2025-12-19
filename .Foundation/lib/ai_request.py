#!/usr/bin/env python3

"""Unified AI request adapter for Foundation phases."""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request


class AIRequestError(RuntimeError):
    """Raised when an AI provider call fails."""


def _read_prompt() -> str:
    prompt = sys.stdin.read()
    if not prompt.strip():
        raise AIRequestError("Prompt content is empty")
    return prompt


def _http_post(url: str, headers: dict[str, str], payload: dict) -> dict:
    data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(url=url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            body = response.read().decode("utf-8")
            return json.loads(body)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="ignore")
        raise AIRequestError(f"HTTP {exc.code} from provider: {detail}") from exc
    except urllib.error.URLError as exc:
        raise AIRequestError(f"Provider request failed: {exc}") from exc


def request_openai(prompt: str, model: str, max_tokens: int) -> str:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise AIRequestError("OPENAI_API_KEY is not set")

    url = os.environ.get("OPENAI_API_BASE", "https://api.openai.com")
    url = url.rstrip("/") + "/v1/chat/completions"

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": "You are a meticulous senior engineer."},
            {"role": "user", "content": prompt},
        ],
        "max_tokens": max_tokens,
        "temperature": float(os.environ.get("OPENAI_TEMPERATURE", "0.2")),
    }

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    response = _http_post(url, headers, payload)
    try:
        return response["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise AIRequestError(f"Unexpected OpenAI response structure: {response}") from exc


def request_anthropic(prompt: str, model: str, max_tokens: int) -> str:
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        raise AIRequestError("ANTHROPIC_API_KEY is not set")

    url = "https://api.anthropic.com/v1/messages"
    payload = {
        "model": model,
        "max_tokens": max_tokens,
        "messages": [{"role": "user", "content": prompt}],
        "temperature": float(os.environ.get("ANTHROPIC_TEMPERATURE", "0.2")),
    }
    headers = {
        "x-api-key": api_key,
        "anthropic-version": os.environ.get("ANTHROPIC_VERSION", "2023-06-01"),
        "content-type": "application/json",
    }

    response = _http_post(url, headers, payload)
    try:
        return response["content"][0]["text"].strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise AIRequestError(f"Unexpected Anthropic response structure: {response}") from exc


def request_google(prompt: str, model: str, max_tokens: int) -> str:
    api_key = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise AIRequestError("GOOGLE_API_KEY (or GEMINI_API_KEY) is not set")

    base_url = os.environ.get("GOOGLE_API_BASE", "https://generativelanguage.googleapis.com")
    url = base_url.rstrip("/") + f"/v1beta/models/{model}:generateContent?key={api_key}"

    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "maxOutputTokens": max_tokens,
            "temperature": float(os.environ.get("GOOGLE_TEMPERATURE", "0.2")),
        },
    }
    headers = {"content-type": "application/json"}

    response = _http_post(url, headers, payload)
    try:
        return response["candidates"][0]["content"]["parts"][0]["text"].strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise AIRequestError(f"Unexpected Google response structure: {response}") from exc


def request_deepseek(prompt: str, model: str, max_tokens: int) -> str:
    api_key = os.environ.get("DEEPSEEK_API_KEY")
    if not api_key:
        raise AIRequestError("DEEPSEEK_API_KEY is not set")

    url = os.environ.get("DEEPSEEK_API_BASE", "https://api.deepseek.com")
    url = url.rstrip("/") + "/v1/chat/completions"

    payload = {
        "model": model,
        "messages": [
            {"role": "system", "content": "You are a meticulous senior engineer."},
            {"role": "user", "content": prompt},
        ],
        "max_tokens": max_tokens,
        "temperature": float(os.environ.get("DEEPSEEK_TEMPERATURE", "0.2")),
    }
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }

    response = _http_post(url, headers, payload)
    try:
        return response["choices"][0]["message"]["content"].strip()
    except (KeyError, IndexError, TypeError) as exc:
        raise AIRequestError(f"Unexpected DeepSeek response structure: {response}") from exc


PROVIDER_HANDLERS = {
    "openai": request_openai,
    "anthropic": request_anthropic,
    "google": request_google,
    "deepseek": request_deepseek,
}


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="AI provider request helper")
    parser.add_argument("--provider", required=True, choices=list(PROVIDER_HANDLERS.keys()))
    parser.add_argument("--model", required=True)
    parser.add_argument("--max-tokens", type=int, default=3500)
    return parser.parse_args()


def main() -> None:
    args = parse_arguments()
    prompt = _read_prompt()
    handler = PROVIDER_HANDLERS[args.provider]
    result = handler(prompt, args.model, args.max_tokens)
    if not result:
        raise AIRequestError("Provider returned an empty response body")
    sys.stdout.write(result)


if __name__ == "__main__":
    try:
        main()
    except AIRequestError as exc:
        sys.stderr.write(f"AI error: {exc}\n")
        sys.exit(1)


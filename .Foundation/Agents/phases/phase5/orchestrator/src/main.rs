use clap::Parser;

use orch::tui::install_panic_hook;
use orch::{headless::run_command, run, CliArgs, Config};

fn main() -> std::process::ExitCode {
    if let Err(e) = color_eyre::install() {
        eprintln!("Failed to install error reporter: {}", e);
        return std::process::ExitCode::FAILURE;
    }
    install_panic_hook();

    let args = CliArgs::parse();
    if args.command.is_some() {
        return run_command(args);
    }
    let config = match Config::build(args) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("{:#}", e);
            return std::process::ExitCode::FAILURE;
        }
    };

    match run(config) {
        Ok(()) => std::process::ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("{:#}", e);
            std::process::ExitCode::FAILURE
        }
    }
}

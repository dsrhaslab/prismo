const PROGRESS_WIDTH: usize = 30;

fn term_width() -> usize {
    use terminal_size::{terminal_size, Width};
    terminal_size().map(|(Width(w), _)| w as usize).unwrap_or(80)
}

pub fn log_labeled(label: &str, value: impl std::fmt::Display) {
    let prefix = "::".cyan();
    let total_len = prefix.len() + label.len() + value.to_string().len() + 1;
    let pad = term_width().saturating_sub(total_len).max(1);
    println!("{} {}{}{}", prefix, label, " ".repeat(pad), value);
}

use {colored::Colorize, std::cell::Cell};

thread_local! {
    static LEFT_WIDTH: Cell<usize> = Cell::new(0);
}

pub fn log_workload_start(
    progress: &str,
    workload_name: &str,
) {
    use std::io::Write;
    use colored::Colorize;
    let left_w = progress.len() + 1 + workload_name.len().max(PROGRESS_WIDTH);
    LEFT_WIDTH.with(|c| c.set(left_w));
    print!("{} {:<PROGRESS_WIDTH$}", progress.cyan(), workload_name);
    let _ = std::io::stdout().flush();
}

fn print_result_right(result: &str, result_plain_len: usize) {
    let left_w = LEFT_WIDTH.with(|c| c.get());
    let pad = term_width().saturating_sub(left_w + result_plain_len).max(1);
    println!("{}{}", " ".repeat(pad), result);
}

pub fn log_workload_ok(rep_label: &str, elapsed: &str) {
    use colored::Colorize;
    let plain_len = rep_label.len() + 1 + 2 + 1 + 1 + elapsed.len() + 1;
    print_result_right(
        &format!("{} {} {}", rep_label, "OK".green(), format!("({})", elapsed).dimmed()),
        plain_len,
    );
}

pub fn log_workload_fail(rep_label: &str, details: &str) {
    use colored::Colorize;
    let plain_len = rep_label.len() + 1 + 4 + 1 + details.len();
    print_result_right(
        &format!("{} {} {}", rep_label, "FAIL".red(), details.dimmed()),
        plain_len,
    );
}

pub fn log_banner(title: &str) {
    use colored::Colorize;
    let w = term_width();
    println!("{}", "━".repeat(w).bold());
    println!("{}", format!("  {}", title).bold());
    println!("{}", "━".repeat(w).bold());
}

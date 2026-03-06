macro_rules! log_info {
    ($($arg:tt)*) => {{
        use colored::Colorize;
        println!("{} {}", "::".cyan(), format!($($arg)*));
    }};
}

macro_rules! log_ok {
    ($($arg:tt)*) => {{
        use colored::Colorize;
        println!("{} {}", "::".green(), format!($($arg)*));
    }};
}

macro_rules! log_fail {
    ($($arg:tt)*) => {{
        use colored::Colorize;
        println!("{} {}", "::".red(), format!($($arg)*));
    }};
}

macro_rules! log_dim {
    ($($arg:tt)*) => {{
        use colored::Colorize;
        println!("{} {}", "::".yellow(), format!("{}", format!($($arg)*)).dimmed());
    }};
}

macro_rules! log_banner {
    ($text:expr) => {{
        println!();
        println!("╔{}╗", "═".repeat(60));
        println!("║{:^width$}║", $text, width = 60);
        println!("╚{}╝", "═".repeat(60));
        println!();
    }};
}

macro_rules! log_section {
    ($title:expr) => {{
        use colored::Colorize;
        println!();
        println!("{}", "━".repeat(64).bold());
        println!("{}", format!("  {}", $title).bold());
        println!("{}", "━".repeat(64).bold());
    }};
}

pub(crate) use {log_banner, log_dim, log_fail, log_info, log_ok, log_section};

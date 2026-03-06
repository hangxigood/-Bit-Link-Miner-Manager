// CLI integration test for power mode read/write
// cargo run --bin test_power_mode
use rust_lib_frontend::client::antminer_web::AntminerWebClient;

fn mode_label(m: u8) -> &'static str {
    match m {
        0 => "Normal",
        1 => "Sleep",
        2 => "LPM",
        _ => "Unknown",
    }
}

#[tokio::main]
async fn main() {
    let ip = "192.168.56.59";
    let user = "root";
    let pass = "root";

    // --- Step 1: Read current mode ---
    println!("=== Step 1: Read current mode from {} ===", ip);
    let current = match AntminerWebClient::read_power_mode(ip, user, pass).await {
        Ok(m) => {
            println!("✅  power_mode = {} ({})", m, mode_label(m));
            m
        }
        Err(e) => {
            println!("❌  read_power_mode failed: {}", e);
            return;
        }
    };

    if current != 1 {
        println!("⚠️  Expected Sleep (1), got {}. Stopping to avoid accidental mode change.", current);
        return;
    }

    // --- Step 2: Set to Normal ---
    println!("\n=== Step 2: Set to Normal (0) ===");
    match AntminerWebClient::set_power_mode(ip, user, pass, 0).await {
        Ok(_) => println!("✅  set_power_mode(0) sent — miner will reboot, waiting 30s..."),
        Err(e) => {
            println!("❌  set_power_mode failed: {}", e);
            return;
        }
    }

    // Wait for miner to reboot and come back up
    for i in (1..=30).rev() {
        print!("\r   Waiting {}s...   ", i);
        tokio::time::sleep(std::time::Duration::from_secs(1)).await;
    }
    println!("\r   Done waiting.       ");

    // --- Step 3: Read back to confirm ---
    println!("\n=== Step 3: Read mode after reboot ===");
    match AntminerWebClient::read_power_mode(ip, user, pass).await {
        Ok(m) => {
            println!("✅  power_mode = {} ({})", m, mode_label(m));
            if m == 0 {
                println!("🎉  Normal mode confirmed!");
            } else {
                println!("⚠️  Expected Normal (0), got {} — mode change may not have worked", m);
            }
        }
        Err(e) => println!("❌  read_power_mode failed after reboot: {}", e),
    }

    // --- Step 4: Restore Sleep ---
    println!("\n=== Step 4: Restore to Sleep (1) ===");
    match AntminerWebClient::set_power_mode(ip, user, pass, 1).await {
        Ok(_) => println!("✅  set_power_mode(1) sent — miner will reboot, waiting 30s..."),
        Err(e) => {
            println!("❌  set_power_mode failed: {}", e);
            return;
        }
    }

    for i in (1..=30).rev() {
        print!("\r   Waiting {}s...   ", i);
        tokio::time::sleep(std::time::Duration::from_secs(1)).await;
    }
    println!("\r   Done waiting.       ");

    // --- Step 5: Final read ---
    println!("\n=== Step 5: Final read ===");
    match AntminerWebClient::read_power_mode(ip, user, pass).await {
        Ok(m) => {
            println!("✅  power_mode = {} ({})", m, mode_label(m));
            if m == 1 {
                println!("🎉  Restored to Sleep — full cycle OK!");
            } else {
                println!("⚠️  Expected Sleep (1), got {}", m);
            }
        }
        Err(e) => println!("❌  read_power_mode failed on final check: {}", e),
    }
}

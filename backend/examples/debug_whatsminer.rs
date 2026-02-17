use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;
use tokio::time::{timeout, Duration};
use std::env;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();
    let ip = if args.len() > 1 { &args[1] } else { "192.168.56.192" };
    let port = 4028;

    println!("Connecting to {}:{}...", ip, port);

    // Commands to test
    let commands = vec![
        "version", 
        "summary", 
        "get_token", // Some require token
        "set_led|auto", // API v2 style?
        "set_led|blink",
        "set_led|light",
    ];

    for cmd_str in commands {
        println!("\n--- Sending command: {} ---", cmd_str);
        let parts: Vec<&str> = cmd_str.split('|').collect();
        let cmd = parts[0];
        let param = if parts.len() > 1 { parts[1] } else { "" };
        
        match send_command(ip, port, cmd, param).await {
            Ok(response) => println!("Response:\n{}", response),
            Err(e) => eprintln!("Error: {}", e),
        }
    }

    Ok(())
}

async fn send_command(ip: &str, port: u16, command: &str, parameter: &str) -> Result<String, Box<dyn std::error::Error>> {
    let address = format!("{}:{}", ip, port);
    let timeout_duration = Duration::from_millis(2000);
    
    // Create request
    let request = serde_json::json!({
        "command": command,
        "parameter": parameter
    });
    let request_json = request.to_string();

    let mut stream = timeout(timeout_duration, TcpStream::connect(&address)).await??;
    stream.write_all(request_json.as_bytes()).await?;

    let mut buffer = Vec::new();
    let _ = timeout(timeout_duration, stream.read_to_end(&mut buffer)).await?;

    let response = String::from_utf8_lossy(&buffer).to_string();
    Ok(response)
}

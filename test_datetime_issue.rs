use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[derive(Debug, Serialize, Deserialize)]
struct TestDto {
    updated_at: DateTime<Utc>,
}

fn main() {
    // 模拟从SQLite读取的datetime
    let sqlite_datetime = "2026-05-07 12:12:37";

    println!("Testing DateTime serialization issue...\n");
    println!("SQLite datetime: {}", sqlite_datetime);

    // 解析SQLite格式
    let naive = chrono::NaiveDateTime::parse_from_str(sqlite_datetime, "%Y-%m-%d %H:%M:%S")
        .expect("Failed to parse");

    let dt = DateTime::<Utc>::from_naive_utc_and_offset(naive, Utc);

    println!("Parsed DateTime: {}", dt);
    println!("RFC3339 format: {}", dt.to_rfc3339());

    // 测试序列化
    let dto = TestDto { updated_at: dt };

    match serde_json::to_string(&dto) {
        Ok(json) => {
            println!("\n✓ Serialization SUCCESS:");
            println!("{}", json);

            // 测试反序列化
            match serde_json::from_str::<TestDto>(&json) {
                Ok(_) => println!("\n✓ Deserialization SUCCESS"),
                Err(e) => println!("\n✗ Deserialization FAILED: {}", e),
            }
        }
        Err(e) => {
            println!("\n✗ Serialization FAILED: {}", e);
        }
    }

    // 测试错误的格式
    println!("\n--- Testing with SQLite format directly (should fail) ---");
    let bad_json = format!(r#"{{"updated_at":"{}"}}"#, sqlite_datetime);
    println!("JSON: {}", bad_json);

    match serde_json::from_str::<TestDto>(&bad_json) {
        Ok(_) => println!("✓ Parsed successfully (unexpected)"),
        Err(e) => println!("✗ Parse failed (expected): {}", e),
    }
}

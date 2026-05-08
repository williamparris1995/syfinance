// 快速测试DateTime序列化
use serde_json;

fn main() {
    // 测试chrono DateTime序列化
    let dt_str = "2026-05-07T12:12:37Z";

    println!("Testing: {}", dt_str);
    println!(
        "Character at position 3: '{}'",
        dt_str.chars().nth(3).unwrap()
    );

    // 这应该是 '6'，但如果错误说是 't'，那意味着某处的字符串是不同的

    // 可能的错误字符串
    let possible_error = "2026-05-07 12:12:37";
    println!("\nIf parsing SQLite format: {}", possible_error);
    println!(
        "Character at position 10: '{}'",
        possible_error.chars().nth(10).unwrap()
    );

    // 或者是在尝试解析时
    let test_json = r#"{"updated_at":"2026-05-07 12:12:37"}"#;
    println!("\nTrying to parse: {}", test_json);
}

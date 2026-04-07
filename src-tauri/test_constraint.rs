use rusqlite::{Connection, Result};

fn main() -> Result<()> {
    let conn = Connection::open("test.db")?;
    
    println!("Testing double-entry constraint...\n");
    
    // Create test transaction
    conn.execute(
        "INSERT INTO transactions (id, transaction_date, description) 
         VALUES ('test-txn-001', '2026-04-07', 'Test unbalanced transaction')",
        [],
    )?;
    println!("✓ Created test transaction");
    
    // Create test accounts
    conn.execute(
        "INSERT INTO accounts (id, name, account_type, chart_of_account_code, currency_code, balance)
         VALUES ('test-acc-001', 'Test Account 1', 'cash', '1001', 'CNY', 0.00)",
        [],
    )?;
    conn.execute(
        "INSERT INTO accounts (id, name, account_type, chart_of_account_code, currency_code, balance)
         VALUES ('test-acc-002', 'Test Account 2', 'bank', '1002', 'CNY', 0.00)",
        [],
    )?;
    println!("✓ Created test accounts");
    
    // Insert first entry (debit 100)
    conn.execute(
        "INSERT INTO transaction_entries (id, transaction_id, account_id, chart_of_account_code, debit_amount, credit_amount)
         VALUES ('test-entry-001', 'test-txn-001', 'test-acc-001', '1001', 100.00, NULL)",
        [],
    )?;
    println!("✓ Inserted first entry: debit 100.00");
    
    // Try to insert unbalanced entry (credit 50) - should FAIL
    println!("\nAttempting to insert unbalanced entry (credit 50.00)...");
    match conn.execute(
        "INSERT INTO transaction_entries (id, transaction_id, account_id, chart_of_account_code, debit_amount, credit_amount)
         VALUES ('test-entry-002', 'test-txn-001', 'test-acc-002', '1002', NULL, 50.00)",
        [],
    ) {
        Ok(_) => {
            println!("✗ CONSTRAINT FAILED: Unbalanced entry was accepted!");
            std::process::exit(1);
        }
        Err(e) => {
            println!("✓ CONSTRAINT ENFORCED: {}", e);
            println!("\nDouble-entry bookkeeping constraint is working correctly!");
        }
    }
    
    Ok(())
}

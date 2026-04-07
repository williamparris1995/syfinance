#[allow(dead_code)]
pub trait AccountRepository: Send + Sync {}

#[allow(dead_code)]
pub trait TransactionRepository: Send + Sync {}

#[allow(dead_code)]
pub trait DebtRepository: Send + Sync {}

#[allow(dead_code)]
pub trait ReminderRepository: Send + Sync {}

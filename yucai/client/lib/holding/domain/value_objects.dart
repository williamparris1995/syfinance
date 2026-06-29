/// 证券类型(对齐 proto SecurityType,域枚举从 0 起,无 UNSPECIFIED 占位)。
///
/// 注意 off-by-one:proto SECURITY_TYPE_UNSPECIFIED=0 / STOCK=1 / ... / OTHER=7,
/// 而域枚举 stock=0 / ... / other=6。data 层 mapper 按符号 NAME 显式映射,
/// 绝不按 int 强转(参见 debt domain DebtType 同款处理)。
enum SecurityType { stock, fund, etf, bond, gold, option, other }

/// 持仓交易类型(对齐 proto TradeType,域枚举从 0 起,无 UNSPECIFIED 占位)。
///
/// 同样 off-by-one:proto TRADE_TYPE_UNSPECIFIED=0 / BUY=1 / SELL=2 /
/// DIVIDEND=3 / SPLIT=4,域枚举 buy=0 / sell=1 / dividend=2 / split=3。
/// data 层 mapper 按 NAME 映射。
enum TradeType { buy, sell, dividend, split }

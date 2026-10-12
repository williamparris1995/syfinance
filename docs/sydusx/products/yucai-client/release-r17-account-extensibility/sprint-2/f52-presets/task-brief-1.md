# T1 预设目录 domain 常量
新文件 yucai/client/lib/account/domain/account_presets.dart:`AccountPreset{final String name; final String institution; final int? billingDay; final int? repaymentDay; final String hint;}`(const 构造)+ `const accountPresets = <AccountPreset>[花呗(蚂蚁消费金融,1,9,hint 空)/京东白条(京东,,,,账单日按激活日,建后可改)/美团月付(美团,同)/微信分付(腾讯,同)]`(category 恒 creditCard 不入字段,注释钉死)。纯 domain 零依赖。
测试 test/account/domain/account_presets_test.dart:目录恰四条/字段完备/花呗 1+9/白条类日期 null 且 hint 非空。只跑本文件。

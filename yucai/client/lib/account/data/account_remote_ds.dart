import 'package:fixnum/fixnum.dart';
import 'package:injectable/injectable.dart';
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart' as tspb;

import 'package:yucai_client/account/data/mappers/account_mapper.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/account/v1/account.pb.dart' as pb;
import 'package:yucai_client/proto/account/v1/account.pbgrpc.dart' as grpc;
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;

/// Wraps the generated AccountServiceClient. Throws GrpcError on failure
/// (caught and mapped by AccountRepositoryImpl).
///
/// List/Create/Update/Get are wrapped in AuthRetryCaller: a 401 (expired access
/// token) triggers a transparent refresh + single retry.
@LazySingleton()
class AccountRemoteDataSource {
  AccountRemoteDataSource(this._grpcClient, this._retry, AccountMapper mapper)
      : _mapper = mapper {
    _client = grpc.AccountServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  final AccountMapper _mapper;
  late final grpc.AccountServiceClient _client;

  Future<List<Account>> list() async {
    return _retry.call(() async {
      // 循环分页拿全量账户(含 expense/income 分类账户),避免 pageSize 限制
      // 漏分类账户 → 交易分录/卡显示 #id。
      final all = <Account>[];
      String? pageToken;
      do {
        final res = await _client.listAccounts(pb.ListAccountsRequest(
          page: common.PageRequest(pageSize: 100, pageToken: pageToken ?? ''),
        ));
        all.addAll(res.accounts.map(_mapper.toDomain).toList());
        final next = res.page.nextPageToken;
        pageToken = next.isNotEmpty ? next : null;
      } while (pageToken != null);
      return all;
    });
  }

  Future<Account> create(CreateAccountParams params) async {
    return _retry.call(() async {
      final req = pb.CreateAccountRequest(
        name: params.name,
        accountType: params.accountType.toProto(),
        category: accountCategoryToProto(params.category),
        currencyCode: params.currencyCode,
        initialBalanceCents: Int64(params.initialBalanceCents),
        ownership: params.ownership.toProto(),
        icon: params.icon,
        color: params.color,
        institution: params.institution,
        creditLimitCents: Int64(params.creditLimitCents),
      );
      if (params.parentId.isNotEmpty) req.parentId = params.parentId;
      _applyCreateFields(req, params);
      final res = await _client.createAccount(req);
      return _mapper.toDomain(res.account);
    });
  }

  Future<Account> getById(String id) async {
    return _retry.call(() async {
      final res = await _client.getAccount(pb.GetAccountRequest(id: id));
      return _mapper.toDomain(res.account);
    });
  }

  Future<Account> update(UpdateAccountParams params) async {
    return _retry.call(() async {
      final req = pb.UpdateAccountRequest(
        id: params.id,
        version: Int64(params.version),
        name: params.name,
        icon: params.icon,
        color: params.color,
        institution: params.institution,
        creditLimitCents: Int64(params.creditLimitCents),
      );
      // NOTE: proto UpdateAccountRequest has no parentId field; editing a
      // category's parent is not persistable via the account update path
      // (CategoryService.UpdateCategoryRequest does — not wired here).
      if (params.status != null) req.status = params.status!.toProto();
      _applyUpdateFields(req, params);
      final res = await _client.updateAccount(req);
      return _mapper.toDomain(res.account);
    });
  }

  Future<void> delete(String id) async {
    return _retry.call(() async {
      await _client.deleteAccount(pb.DeleteAccountRequest(id: id));
    });
  }

  /// Copies the 25 nullable category-specific fields from [p] onto [req] when
  /// present. Strings are set only when non-empty (proto3 optional string);
  /// scalars and timestamps only when non-null.
  ///
  /// Two near-identical overloads exist because [pb.CreateAccountRequest] and
  /// [pb.UpdateAccountRequest] are independent generated classes with no shared
  /// setter interface; keeping the field list in one file (vs. duplicated across
  /// create/update bodies) limits drift.
  static void _applyCreateFields(
      pb.CreateAccountRequest req, CreateAccountParams p) {
    if (p.cardNumberTail.isNotEmpty) req.cardNumberTail = p.cardNumberTail;
    if (p.notes.isNotEmpty) req.notes = p.notes;
    if (p.openingDate != null) req.openingDate = _ts(p.openingDate!);
    if (p.interestRate != null) req.interestRate = p.interestRate!;
    if (p.creditBillingDay != null) req.creditBillingDay = p.creditBillingDay!;
    if (p.creditRepaymentDay != null) {
      req.creditRepaymentDay = p.creditRepaymentDay!;
    }
    if (p.creditAnnualFeeCents != null) {
      req.creditAnnualFeeCents = Int64(p.creditAnnualFeeCents!);
    }
    if (p.investCostCents != null) req.investCostCents = Int64(p.investCostCents!);
    if (p.investMarketValueCents != null) {
      req.investMarketValueCents = Int64(p.investMarketValueCents!);
    }
    if (p.investReturnYtd != null) req.investReturnYtd = p.investReturnYtd!;
    if (p.fixedPrincipalCents != null) {
      req.fixedPrincipalCents = Int64(p.fixedPrincipalCents!);
    }
    if (p.fixedStartDate != null) req.fixedStartDate = _ts(p.fixedStartDate!);
    if (p.fixedMaturityDate != null) {
      req.fixedMaturityDate = _ts(p.fixedMaturityDate!);
    }
    if (p.fixedTermMonths != null) req.fixedTermMonths = p.fixedTermMonths!;
    if (p.goldProductType.isNotEmpty) req.goldProductType = p.goldProductType;
    if (p.goldQuantity != null) req.goldQuantity = p.goldQuantity!;
    if (p.goldBuyPriceCents != null) {
      req.goldBuyPriceCents = Int64(p.goldBuyPriceCents!);
    }
    if (p.goldCurrentPriceCents != null) {
      req.goldCurrentPriceCents = Int64(p.goldCurrentPriceCents!);
    }
    if (p.estatePurchasePriceCents != null) {
      req.estatePurchasePriceCents = Int64(p.estatePurchasePriceCents!);
    }
    if (p.estateCurrentValueCents != null) {
      req.estateCurrentValueCents = Int64(p.estateCurrentValueCents!);
    }
    if (p.estatePurchaseDate != null) {
      req.estatePurchaseDate = _ts(p.estatePurchaseDate!);
    }
    if (p.estateDepreciationRate != null) {
      req.estateDepreciationRate = p.estateDepreciationRate!;
    }
    if (p.loanOriginalCents != null) {
      req.loanOriginalCents = Int64(p.loanOriginalCents!);
    }
    if (p.loanRemainingCents != null) {
      req.loanRemainingCents = Int64(p.loanRemainingCents!);
    }
    if (p.loanMonthlyCents != null) {
      req.loanMonthlyCents = Int64(p.loanMonthlyCents!);
    }
    if (p.loanNextPaymentDate != null) {
      req.loanNextPaymentDate = _ts(p.loanNextPaymentDate!);
    }
  }

  static void _applyUpdateFields(
      pb.UpdateAccountRequest req, UpdateAccountParams p) {
    if (p.cardNumberTail.isNotEmpty) req.cardNumberTail = p.cardNumberTail;
    if (p.notes.isNotEmpty) req.notes = p.notes;
    if (p.openingDate != null) req.openingDate = _ts(p.openingDate!);
    if (p.interestRate != null) req.interestRate = p.interestRate!;
    if (p.creditBillingDay != null) req.creditBillingDay = p.creditBillingDay!;
    if (p.creditRepaymentDay != null) {
      req.creditRepaymentDay = p.creditRepaymentDay!;
    }
    if (p.creditAnnualFeeCents != null) {
      req.creditAnnualFeeCents = Int64(p.creditAnnualFeeCents!);
    }
    if (p.investCostCents != null) req.investCostCents = Int64(p.investCostCents!);
    if (p.investMarketValueCents != null) {
      req.investMarketValueCents = Int64(p.investMarketValueCents!);
    }
    if (p.investReturnYtd != null) req.investReturnYtd = p.investReturnYtd!;
    if (p.fixedPrincipalCents != null) {
      req.fixedPrincipalCents = Int64(p.fixedPrincipalCents!);
    }
    if (p.fixedStartDate != null) req.fixedStartDate = _ts(p.fixedStartDate!);
    if (p.fixedMaturityDate != null) {
      req.fixedMaturityDate = _ts(p.fixedMaturityDate!);
    }
    if (p.fixedTermMonths != null) req.fixedTermMonths = p.fixedTermMonths!;
    if (p.goldProductType.isNotEmpty) req.goldProductType = p.goldProductType;
    if (p.goldQuantity != null) req.goldQuantity = p.goldQuantity!;
    if (p.goldBuyPriceCents != null) {
      req.goldBuyPriceCents = Int64(p.goldBuyPriceCents!);
    }
    if (p.goldCurrentPriceCents != null) {
      req.goldCurrentPriceCents = Int64(p.goldCurrentPriceCents!);
    }
    if (p.estatePurchasePriceCents != null) {
      req.estatePurchasePriceCents = Int64(p.estatePurchasePriceCents!);
    }
    if (p.estateCurrentValueCents != null) {
      req.estateCurrentValueCents = Int64(p.estateCurrentValueCents!);
    }
    if (p.estatePurchaseDate != null) {
      req.estatePurchaseDate = _ts(p.estatePurchaseDate!);
    }
    if (p.estateDepreciationRate != null) {
      req.estateDepreciationRate = p.estateDepreciationRate!;
    }
    if (p.loanOriginalCents != null) {
      req.loanOriginalCents = Int64(p.loanOriginalCents!);
    }
    if (p.loanRemainingCents != null) {
      req.loanRemainingCents = Int64(p.loanRemainingCents!);
    }
    if (p.loanMonthlyCents != null) {
      req.loanMonthlyCents = Int64(p.loanMonthlyCents!);
    }
    if (p.loanNextPaymentDate != null) {
      req.loanNextPaymentDate = _ts(p.loanNextPaymentDate!);
    }
  }
}

tspb.Timestamp _ts(DateTime d) => tspb.Timestamp.fromDateTime(d);

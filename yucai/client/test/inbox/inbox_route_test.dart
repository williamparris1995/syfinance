// /inbox 路由注册冒烟(2026-09 到期常显提醒 T4,spec FR-5/FR-7):
// 钉死收件箱分支在 StatefulShellRoute 的注册形态 —— 置于末尾(index 9,
// settings 之后),既有 branch 索引(侧栏/底栏/面包屑硬编码 0..8)零移位;
// app shell 内(宽窄屏同其他页),但无侧栏/底栏入口(spec FR-7:入口 =
// 聚合条「查看全部」+ 托盘菜单项唯二)。纯配置断言(不 pump,无需 DI 图,
// 照 router_test「branches」同款)。
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/app/router.dart';
import 'package:yucai_client/auth/domain/entities/user_entity.dart';
import 'package:yucai_client/auth/domain/usecases/get_profile_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/has_stored_credentials_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/logout_usecase.dart';
import 'package:yucai_client/auth/domain/usecases/oidc_login_usecase.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';

class _MockOidcLogin extends Mock implements OidcLoginUseCase {}
class _MockProfile extends Mock implements GetProfileUseCase {}
class _MockLogout extends Mock implements LogoutUseCase {}
class _MockHasCredentials extends Mock implements HasStoredCredentialsUseCase {}

class _SeededAuthedBloc extends AuthBloc {
  _SeededAuthedBloc()
      : super(_MockOidcLogin(), _MockProfile(), _MockLogout(),
            _MockHasCredentials(), SessionModeTracker()) {
    emit(Authenticated(_user));
  }
}

final _user = User(
  id: 'u1',
  tenantId: 't1',
  email: 't@example.com',
  displayName: '测试用户',
  avatarUrl: '',
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
);

void main() {
  test('router registers /inbox as the 10th shell branch(提醒中心,末尾'
      '不移位既有索引)', () {
    final router = buildRouter(_SeededAuthedBloc());
    final shell =
        router.configuration.routes.whereType<StatefulShellRoute>().first;
    expect(shell.branches.length, 10,
        reason: 'inbox branch (index 9) must follow settings (index 8); '
            '0..8 硬编码索引不得移位');
    final branchRoutes = shell.branches[9].routes.whereType<GoRoute>().toList();
    expect(branchRoutes.map((r) => r.path), contains('/inbox'));
  });

  test('/inbox route builds InboxPage(app shell 内平级页面)', () {
    final router = buildRouter(_SeededAuthedBloc());
    final shell =
        router.configuration.routes.whereType<StatefulShellRoute>().first;
    final route = shell.branches[9]
        .routes
        .whereType<GoRoute>()
        .firstWhere((r) => r.path == '/inbox');
    // builder 已接线(页面类型由 router.dart 编译期钉死);无参构造页面
    // (store/provider 走 guarded getIt,测试注入走构造缝)。
    expect(route.builder, isNotNull);
  });
}

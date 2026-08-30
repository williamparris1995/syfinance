/* 御财 v2 原型 · 主题切换(暗=墨鎏金 / 亮=晨白),localStorage 记忆 */
(function () {
  var root = document.documentElement;
  var btn = document.getElementById('themeToggle');
  if (!btn) return;
  btn.addEventListener('click', function () {
    var next = root.dataset.theme === 'dark' ? 'light' : 'dark';
    root.dataset.theme = next;
    try { localStorage.setItem('yc2-theme', next); } catch (e) { /* file:// 某些环境禁用 */ }
  });
})();

type RouteShellProps = {
  title: string;
};

export function RouteShell({ title }: RouteShellProps) {
  return (
    <section className="space-y-3">
      <h1 className="text-3xl font-semibold text-slate-50">{title}</h1>
      <p className="text-sm text-slate-400">Route shell.</p>
    </section>
  );
}

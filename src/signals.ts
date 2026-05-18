let stop = false;

export function onShutdown(cb: () => void): void {
  const h = () => {
    if (stop) return;
    stop = true;
    cb();
  };
  process.on("SIGINT", h);
  process.on("SIGTERM", h);
}

export function shouldStop(): boolean {
  return stop;
}

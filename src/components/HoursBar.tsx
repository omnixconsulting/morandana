export function HoursBar() {
  return (
    <div className="bg-coral-deep text-white">
      <div className="mx-auto flex max-w-6xl flex-col items-center justify-center gap-1 px-5 py-4 text-center text-sm sm:flex-row sm:gap-8 sm:text-base">
        <p>
          <span className="font-semibold">Lun&nbsp;–&nbsp;Sáb</span>{" "}
          <span className="text-white/85">7:30 am – 7:00 pm</span>
        </p>
        <span className="hidden text-white/50 sm:inline">·</span>
        <p>
          <span className="font-semibold">Domingo</span>{" "}
          <span className="text-white/85">7:30 am – 4:00 pm</span>
        </p>
      </div>
    </div>
  );
}

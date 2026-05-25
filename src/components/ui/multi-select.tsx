import * as React from "react"
import { Popover } from "@base-ui/react/popover"
import { Checkbox } from "@base-ui/react/checkbox"
import { cn } from "@/lib/utils"
import { ChevronDownIcon } from "lucide-react"

interface MultiSelectProps {
  options: { id: string; label: string }[]
  value: string[]
  onChange: (value: string[]) => void
  placeholder: string
  selectAllLabel: string
  className?: string
}

export function MultiSelect({
  options,
  value,
  onChange,
  placeholder,
  selectAllLabel,
  className,
}: MultiSelectProps) {
  const [open, setOpen] = React.useState(false)

  const allSelected = options.length > 0 && value.length === options.length
  const indeterminate = value.length > 0 && !allSelected

  const handleToggle = (id: string) => {
    if (id === "__all__") {
      if (allSelected) {
        onChange([])
      } else {
        onChange(options.map((o) => o.id))
      }
      return
    }
    if (value.includes(id)) {
      onChange(value.filter((v) => v !== id))
    } else {
      onChange([...value, id])
    }
  }

  const selectedLabels = value
    .map((id) => options.find((o) => o.id === id)?.label)
    .filter(Boolean)
    .join(", ")

  return (
    <Popover.Root open={open} onOpenChange={setOpen}>
      <Popover.Trigger
        aria-label={placeholder}
        className={cn(
          "flex h-7 w-fit items-center justify-between gap-1 rounded-lg border border-input bg-transparent py-1 pr-1.5 pl-2.5 text-xs whitespace-nowrap transition-colors outline-none select-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 min-w-[120px] max-w-[180px]",
          className,
        )}
      >
        <span className="flex min-w-0 flex-1 items-center gap-1.5 text-left">
          {value.length > 0 ? (
            <>
              <span className="truncate">{selectedLabels}</span>
              <span className="inline-flex h-4 min-w-4 shrink-0 items-center justify-center rounded-full bg-primary px-1 text-[10px] font-medium text-primary-foreground">
                {value.length}
              </span>
            </>
          ) : (
            <span className="text-muted-foreground">{placeholder}</span>
          )}
        </span>
        <ChevronDownIcon className="size-3.5 shrink-0 text-muted-foreground" />
      </Popover.Trigger>
      <Popover.Portal>
        <Popover.Positioner
          side="bottom"
          sideOffset={4}
          align="start"
          className="z-50"
        >
          <Popover.Popup className="min-w-[160px] max-h-60 overflow-y-auto rounded-lg bg-popover p-1 text-popover-foreground shadow-md ring-1 ring-foreground/10 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95">
            {/* Select All */}
            <label className="flex cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 hover:bg-accent">
              <Checkbox.Root
                checked={allSelected}
                indeterminate={indeterminate}
                onCheckedChange={() => handleToggle("__all__")}
                className="flex size-4 shrink-0 items-center justify-center rounded border border-input data-[checked]:bg-primary data-[checked]:text-primary-foreground"
              >
                <Checkbox.Indicator className="flex items-center justify-center text-current">
                  <CheckIcon />
                </Checkbox.Indicator>
              </Checkbox.Root>
              <span className="text-sm">{selectAllLabel}</span>
            </label>
            {/* Divider */}
            <div className="mx-1 my-1 h-px bg-border" />
            {/* Options */}
            {options.map((option) => (
              <label
                key={option.id}
                className="flex cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 hover:bg-accent"
              >
                <Checkbox.Root
                  checked={value.includes(option.id)}
                  onCheckedChange={() => handleToggle(option.id)}
                  className="flex size-4 shrink-0 items-center justify-center rounded border border-input data-[checked]:bg-primary data-[checked]:text-primary-foreground"
                >
                  <Checkbox.Indicator className="flex items-center justify-center text-current">
                    <CheckIcon />
                  </Checkbox.Indicator>
                </Checkbox.Root>
                <span className="truncate text-sm">{option.label}</span>
              </label>
            ))}
          </Popover.Popup>
        </Popover.Positioner>
      </Popover.Portal>
    </Popover.Root>
  )
}

function CheckIcon() {
  return (
    <svg width="10" height="10" viewBox="0 0 15 15" fill="currentColor" aria-hidden="true">
      <path
        d="M11.4669 3.72684C11.7558 3.91574 11.8369 4.30308 11.648 4.59198L7.39799 11.092C7.29783 11.2452 7.13556 11.3467 6.95402 11.3699C6.77247 11.3931 6.58989 11.3355 6.45446 11.2124L3.70446 8.71241C3.44905 8.48022 3.43023 8.08494 3.66242 7.82953C3.89461 7.57412 4.28989 7.55529 4.5453 7.78749L6.75292 9.79441L10.6018 3.90792C10.7907 3.61902 11.178 3.53795 11.4669 3.72684Z"
        clipRule="evenodd"
        fillRule="evenodd"
      />
    </svg>
  )
}

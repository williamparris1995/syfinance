import * as React from "react"
import { LucideIcon } from "lucide-react"

import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"

export interface QuickAction {
  id: string
  label: string
  icon: LucideIcon
  onClick: () => void
  variant?: "default" | "outline"
}

export interface QuickActionsProps {
  actions: QuickAction[]
  layout?: "horizontal" | "grid"
}

export function QuickActions({ actions, layout = "grid" }: QuickActionsProps) {
  return (
    <div
      className={cn(
        "w-full gap-3",
        layout === "grid" &&
          "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-2",
        layout === "horizontal" && "flex flex-wrap"
      )}
    >
      {actions.map((action) => {
        const Icon = action.icon
        return (
          <Button
            key={action.id}
            variant={action.variant ?? "outline"}
            onClick={action.onClick}
            className={cn(
              "h-auto flex-col gap-3 py-6",
              layout === "horizontal" && "flex-1"
            )}
          >
            <Icon className="size-6" aria-hidden="true" />
            <span className="text-sm font-medium">{action.label}</span>
          </Button>
        )
      })}
    </div>
  )
}

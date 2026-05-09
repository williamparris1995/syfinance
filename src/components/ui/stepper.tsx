import * as React from "react"
import { Check } from "lucide-react"

import { cn } from "@/lib/utils"

export interface Step {
  id: string
  title: string
  description?: string
}

export interface StepperProps {
  steps: Step[]
  currentStep: number
  onStepClick?: (stepIndex: number) => void
  allowSkip?: boolean
}

export function Stepper({
  steps,
  currentStep,
  onStepClick,
  allowSkip = false,
}: StepperProps) {
  const handleStepClick = (index: number) => {
    if (!onStepClick) return
    
    // Allow clicking on completed steps or current step
    if (index <= currentStep || allowSkip) {
      onStepClick(index)
    }
  }

  return (
    <nav aria-label="Progress" className="w-full">
      <ol
        role="list"
        className="flex flex-col gap-4 md:flex-row md:items-center md:gap-0"
      >
        {steps.map((step, index) => {
          const isCompleted = index < currentStep
          const isCurrent = index === currentStep
          const isPending = index > currentStep
          const isClickable = onStepClick && (index <= currentStep || allowSkip)

          return (
            <li
              key={step.id}
              className={cn(
                "relative flex flex-1 items-center gap-3 md:flex-col md:gap-2",
                index !== steps.length - 1 && "md:pr-8"
              )}
            >
              {/* Connector line - only show on desktop between steps */}
              {index !== steps.length - 1 && (
                <div
                  className="absolute left-5 top-10 hidden h-px w-full md:block md:left-auto md:right-0 md:top-5 md:translate-x-1/2"
                  aria-hidden="true"
                >
                  <div
                    className={cn(
                      "h-full w-full transition-colors",
                      isCompleted ? "bg-primary" : "bg-muted"
                    )}
                  />
                </div>
              )}

              {/* Step content */}
              <div className="flex items-center gap-3 md:flex-col md:gap-2">
                {/* Step indicator */}
                <button
                  type="button"
                  onClick={() => handleStepClick(index)}
                  disabled={!isClickable}
                  className={cn(
                    "relative z-10 flex size-10 shrink-0 items-center justify-center rounded-full border-2 text-sm font-semibold transition-all",
                    isCompleted &&
                      "border-primary bg-primary text-primary-foreground",
                    isCurrent &&
                      "border-primary bg-background text-primary ring-4 ring-primary/20",
                    isPending && "border-muted bg-background text-muted-foreground",
                    isClickable && "cursor-pointer hover:border-primary/80",
                    !isClickable && "cursor-default"
                  )}
                  aria-current={isCurrent ? "step" : undefined}
                  aria-label={`${step.title}${isCompleted ? " (completed)" : isCurrent ? " (current)" : ""}`}
                >
                  {isCompleted ? (
                    <Check className="size-5" aria-hidden="true" />
                  ) : (
                    <span>{index + 1}</span>
                  )}
                </button>

                {/* Step text */}
                <div className="flex min-w-0 flex-col md:items-center md:text-center">
                  <span
                    className={cn(
                      "text-sm font-medium",
                      isCurrent && "text-foreground",
                      isCompleted && "text-foreground",
                      isPending && "text-muted-foreground"
                    )}
                  >
                    {step.title}
                  </span>
                  {step.description && (
                    <span className="text-xs text-muted-foreground">
                      {step.description}
                    </span>
                  )}
                </div>
              </div>
            </li>
          )
        })}
      </ol>
    </nav>
  )
}

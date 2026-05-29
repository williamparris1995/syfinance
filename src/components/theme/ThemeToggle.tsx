import { Moon, Sun, Monitor } from 'lucide-react';
import { Button } from '../ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '../ui/dropdown-menu';
import { useThemeContext } from './ThemeProvider';
import { Theme } from '../../lib/theme';
import { useTranslation } from 'react-i18next';

const themeOptions: { value: Theme; labelKey: string; icon: typeof Sun }[] = [
  { value: 'light', labelKey: 'theme.light', icon: Sun },
  { value: 'dark', labelKey: 'theme.dark', icon: Moon },
  { value: 'system', labelKey: 'theme.system', icon: Monitor },
];

export function ThemeToggle() {
  const { theme, setTheme } = useThemeContext();
  const { t } = useTranslation();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger
        render={
          <Button variant="ghost" size="icon">
            <Sun className="h-5 w-5 rotate-0 scale-100 transition-all dark:-rotate-90 dark:scale-0" />
            <Moon className="absolute h-5 w-5 rotate-90 scale-0 transition-all dark:rotate-0 dark:scale-100" />
            <span className="sr-only">{t('theme.toggleTheme')}</span>
          </Button>
        }
      />
      <DropdownMenuContent align="end">
        {themeOptions.map((option) => (
          <DropdownMenuItem
            key={option.value}
            onClick={() => setTheme(option.value)}
            className={theme === option.value ? 'bg-accent' : ''}
          >
            <option.icon className="mr-2 h-4 w-4" />
            {t(option.labelKey)}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

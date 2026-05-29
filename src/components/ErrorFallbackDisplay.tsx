import { useTranslation } from 'react-i18next';
import { Button } from './ui/button';

interface ErrorFallbackDisplayProps {
  errorMessage: string;
  onRetry: () => void;
}

export function ErrorFallbackDisplay({ errorMessage, onRetry }: ErrorFallbackDisplayProps) {
  const { t } = useTranslation();

  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <div className="max-w-md w-full space-y-4 text-center">
        <div className="space-y-2">
          <h1 className="text-2xl font-bold text-red-600">{t('error.title')}</h1>
          <p className="text-neutral-600">
            {t('error.description')}
          </p>
        </div>
        <div className="p-4 bg-red-50 border border-red-200 rounded-lg text-left">
          <p className="text-sm text-red-800 font-mono break-words">
            {errorMessage}
          </p>
        </div>
        <div className="flex gap-2 justify-center">
          <Button onClick={onRetry}>{t('error.tryAgain')}</Button>
          <Button variant="outline" onClick={() => window.location.reload()}>
            {t('error.reloadPage')}
          </Button>
        </div>
      </div>
    </div>
  );
}

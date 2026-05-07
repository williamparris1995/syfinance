import { useMutation } from '@tanstack/react-query';
import { AlertCircle, CheckCircle2, Copy } from 'lucide-react';
import { useState } from 'react';
import { useNavigate } from '@tanstack/react-router';
import { Button } from '../components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '../components/ui/card';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import { linkDevice, registerDevice, type RegisterResponse } from '../lib/auth';

export function OnboardingPage() {
  const [mode, setMode] = useState<'choice' | 'register' | 'link'>('choice');
  const [registrationData, setRegistrationData] = useState<RegisterResponse | null>(null);
  const [linkAccountId, setLinkAccountId] = useState('');
  const [copied, setCopied] = useState(false);
  const navigate = useNavigate();

  const registerMutation = useMutation({
    mutationFn: registerDevice,
    onSuccess: (data) => {
      setRegistrationData(data);
    },
  });

  const linkMutation = useMutation({
    mutationFn: (accountId: string) => linkDevice(accountId),
    onSuccess: () => {
      navigate({ to: '/' });
    },
  });

  const handleRegister = () => {
    setMode('register');
    registerMutation.mutate();
  };

  const handleLinkDevice = () => {
    if (linkAccountId.trim()) {
      linkMutation.mutate(linkAccountId.trim());
    }
  };

  const handleCopyAccountId = async () => {
    if (registrationData) {
      await navigator.clipboard.writeText(registrationData.account_id);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    }
  };

  const handleComplete = () => {
    navigate({ to: '/' });
  };

  if (mode === 'choice') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-neutral-50 to-neutral-100 p-6">
        <Card className="w-full max-w-md">
          <CardHeader className="text-center">
            <CardTitle className="text-3xl font-bold">Welcome to Finance App</CardTitle>
            <CardDescription className="text-base mt-2">
              Get started by creating a new account or linking an existing device
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <Button
              onClick={handleRegister}
              className="w-full h-12 text-base"
              disabled={registerMutation.isPending}
            >
              {registerMutation.isPending ? 'Creating Account...' : 'Create New Account'}
            </Button>
            <Button
              onClick={() => setMode('link')}
              variant="outline"
              className="w-full h-12 text-base"
            >
              Link Existing Account
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (mode === 'register' && registrationData) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-neutral-50 to-neutral-100 p-6">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle className="text-2xl font-bold">Account Created!</CardTitle>
            <CardDescription>
              Save your Account ID - you'll need it to link other devices
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="bg-amber-50 border border-amber-200 rounded-lg p-4 flex gap-3">
              <AlertCircle className="h-5 w-5 text-amber-600 flex-shrink-0 mt-0.5" />
              <div className="text-sm text-amber-800">
                <p className="font-semibold mb-1">Important: Save this ID!</p>
                <p>
                  You'll need this Account ID to sync data across devices. There's no way to
                  recover it if you lose it.
                </p>
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="account-id">Your Account ID</Label>
              <div className="flex gap-2">
                <Input
                  id="account-id"
                  value={registrationData.account_id}
                  readOnly
                  className="font-mono text-sm"
                />
                <Button
                  variant="outline"
                  size="icon"
                  onClick={handleCopyAccountId}
                  className="flex-shrink-0"
                >
                  {copied ? (
                    <CheckCircle2 className="h-4 w-4 text-green-600" />
                  ) : (
                    <Copy className="h-4 w-4" />
                  )}
                </Button>
              </div>
              <p className="text-xs text-muted-foreground">
                Copy this ID and save it somewhere safe (password manager, notes app, etc.)
              </p>
            </div>

            <div className="bg-neutral-100 rounded-lg p-4 space-y-2">
              <p className="text-sm font-medium">Device ID (for reference)</p>
              <p className="text-xs font-mono text-muted-foreground break-all">
                {registrationData.device_id}
              </p>
            </div>

            <Button onClick={handleComplete} className="w-full h-12 text-base">
              I've Saved My Account ID
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (mode === 'link') {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-neutral-50 to-neutral-100 p-6">
        <Card className="w-full max-w-md">
          <CardHeader>
            <CardTitle className="text-2xl font-bold">Link Existing Account</CardTitle>
            <CardDescription>
              Enter your Account ID from another device to sync your data
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            <div className="space-y-2">
              <Label htmlFor="link-account-id">Account ID</Label>
              <Input
                id="link-account-id"
                placeholder="Enter your Account ID"
                value={linkAccountId}
                onChange={(e) => setLinkAccountId(e.target.value)}
                className="font-mono text-sm"
              />
              <p className="text-xs text-muted-foreground">
                This is the Account ID you saved when you first created your account
              </p>
            </div>

            {linkMutation.isError && (
              <div className="bg-red-50 border border-red-200 rounded-lg p-4 text-sm text-red-700">
                Error linking device: {(linkMutation.error as Error).message}
              </div>
            )}

            <div className="flex gap-2">
              <Button
                variant="outline"
                onClick={() => setMode('choice')}
                className="flex-1"
                disabled={linkMutation.isPending}
              >
                Back
              </Button>
              <Button
                onClick={handleLinkDevice}
                className="flex-1"
                disabled={!linkAccountId.trim() || linkMutation.isPending}
              >
                {linkMutation.isPending ? 'Linking...' : 'Link Device'}
              </Button>
            </div>
          </CardContent>
        </Card>
      </div>
    );
  }

  return null;
}

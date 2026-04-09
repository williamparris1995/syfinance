import '@testing-library/jest-dom/vitest';
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import App from '../App';

describe('App', () => {
  it('renders the finance app shell', () => {
    render(<App />);

    expect(screen.getByRole('heading', { name: /navigation/i })).toBeInTheDocument();
    expect(screen.getByRole('heading', { name: /overview/i })).toBeInTheDocument();
  });
});

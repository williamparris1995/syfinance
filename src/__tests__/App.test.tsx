import '@testing-library/jest-dom/vitest';
import { render } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import App from '../App';

describe('App', () => {
  it('renders the finance app shell', () => {
    const { container } = render(<App />);
    expect(container).toBeTruthy();
  });
});

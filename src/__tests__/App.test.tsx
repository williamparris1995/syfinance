import { render, screen } from '@testing-library/react';
import App from '../App';

describe('App', () => {
  it('renders the finance app landing content', () => {
    render(<App />);

    expect(screen.getByRole('heading', { name: /personal finance manager/i })).toBeInTheDocument();
    expect(screen.getByText(/tauri 2 · react · typescript/i)).toBeInTheDocument();
  });
});

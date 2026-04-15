import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { MantineProvider, createTheme } from '@mantine/core'
import { BrowserRouter } from 'react-router-dom'
import '@mantine/core/styles.css'
import './index.css'
import App from './App.tsx'

/** The Silent Architect — tema derivado do projeto Stitch #6258759638863339324 */
const theme = createTheme({
  primaryColor: 'blue',
  defaultRadius: 'xs',
  fontFamily: 'Inter, sans-serif',
  headings: {
    fontFamily: 'Space Grotesk, sans-serif',
    fontWeight: '600',
  },
  fontSizes: {
    xs: '0.6875rem',
    sm: '0.8125rem',
    md: '0.875rem',
    lg: '1rem',
    xl: '1.125rem',
  },
  spacing: {
    xs: '0.5rem',
    sm: '0.75rem',
    md: '1rem',
    lg: '1.25rem',
    xl: '1.5rem',
  },
  components: {
    AppShell: {
      styles: {
        header: {
          background: 'var(--cc-surface-low)',
          borderBottom: 'none',
        },
        navbar: {
          background: 'var(--cc-surface-low)',
          borderRight: 'none',
        },
        main: {
          background: 'var(--cc-surface)',
        },
      },
    },
    Button: {
      defaultProps: { radius: 'xs' },
    },
    Select: {
      defaultProps: { radius: 'xs' },
    },
    Textarea: {
      defaultProps: { radius: 'xs' },
    },
  },
})

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <MantineProvider theme={theme} defaultColorScheme="dark">
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </MantineProvider>
  </StrictMode>,
)

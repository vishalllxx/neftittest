import { useEffect, useRef } from 'react';
import { useLocation } from 'react-router-dom';

export const ScrollToTop = () => {
  const { pathname } = useLocation();
  const previousPathRef = useRef<string>('');

  useEffect(() => {
    // Store the current path for next comparison
    const previousPath = previousPathRef.current;
    previousPathRef.current = pathname;

    // Scroll to top for non-docs pages
    if (!pathname.startsWith('/docs')) {
      window.scrollTo(0, 0);
      return;
    }

    // For docs pages, only scroll to top if navigating from a non-docs page
    // This preserves sidebar scroll when navigating within docs
    if (previousPath && !previousPath.startsWith('/docs')) {
      window.scrollTo(0, 0);
    }
  }, [pathname]);

  return null;
};

export default ScrollToTop;

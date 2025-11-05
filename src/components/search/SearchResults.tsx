import React, { useCallback } from "react";
import { SearchResult } from "@/utils/search";
import { useNavigate } from "react-router-dom";
import { useDocsNavigation } from "@/contexts/DocsNavigationContext";

interface SearchResultsProps {
  results: SearchResult[];
  searchTerm: string;
  setSearchTerm: (term: string) => void;
  onResultClick?: () => void;
}

const HighlightMatch: React.FC<{ text: string; searchTerm: string }> = ({
  text,
  searchTerm,
}) => {
  if (!searchTerm.trim()) return <>{text}</>;

  const escapeRegex = (str: string) =>
    str.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

  const regex = new RegExp(`(${escapeRegex(searchTerm)})`, "gi");
  const parts = text.split(regex);

  return (
    <>
      {parts.map((part, i) =>
        regex.test(part) ? (
          <mark
            key={i}
            className="bg-yellow-200 text-yellow-900 px-0.5 rounded"
          >
            {part}
          </mark>
        ) : (
          part
        )
      )}
    </>
  );
};

export const SearchResults: React.FC<SearchResultsProps> = ({
  results,
  searchTerm,
  setSearchTerm,
  onResultClick,
}) => {
  const navigate = useNavigate();
  const { handleDocsNavigation } = useDocsNavigation();

  const handleResultClick = useCallback((slug: string) => {
    // Store the current search term
    const currentSearchTerm = searchTerm;
    
    // Close search dropdown
    if (onResultClick) {
      onResultClick();
    }
    
    // Use regular navigation instead of handleDocsNavigation to avoid replace: true
    navigate(`/docs/${slug}`, { state: { fromSearch: true, searchTerm: currentSearchTerm } });
    
    // Close mobile keyboard on mobile devices
    if (window.innerWidth < 1024) {
      const activeElement = document.activeElement as HTMLElement;
      activeElement?.blur();
    }
    
    // Re-focus the search input after a short delay
    const searchInput = document.querySelector('input[type="text"]') as HTMLInputElement;
    if (searchInput) {
      // Store a reference to the input value
      const inputValue = searchInput.value;
      
      // Focus and restore the value after a short delay
      setTimeout(() => {
        searchInput.focus();
        searchInput.value = inputValue;
      }, 50);
    }
    
    // Scroll to top of the page
    window.scrollTo(0, 0);
  }, [navigate, onResultClick, searchTerm]);
  if (!searchTerm.trim()) return null;

  if (results.length === 0) {
    return (
      <div
        className="rounded-lg max-h-[400px] overflow-hidden text-sm"
        style={{ backgroundColor: "#121021" }}
      >
        <p className="text-gray-400">
          No results found for <span className="text-white">"{searchTerm}"</span>
        </p>
      </div>
    );
  }

  return (
    <div
      className="rounded-lg max-h-[400px] overflow-y-auto custom-scrollbar"
      style={{ backgroundColor: "#121021" }}
    >
      <div className="space-y-3 p-2">
        {results.map((result) => (
          <a
            key={result.slug}
            href={`/docs/${result.slug}`}
            onClick={(e) => {
              e.preventDefault();
              handleResultClick(result.slug);
            }}
            className="block p-4 rounded-lg transition-all hover:shadow-lg hover:bg-[#24213d] cursor-pointer"
            style={{ backgroundColor: "#1b1930" }}
          >
            <div className="flex items-center mb-1">
              <span className="text-xs font-medium text-blue-400 bg-blue-900/30 px-2 py-0.5 rounded">
                {result.section}
              </span>
            </div>
            <h3 className="text-lg font-medium text-white">
              <HighlightMatch text={result.title} searchTerm={searchTerm} />
            </h3>
          </a>
        ))}
      </div>
    </div>
  );
};

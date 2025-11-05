import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { useEffect, useState } from "react";
import { useUserProfile } from '@/hooks/useUserProfile';
import { getWalletAddress } from '@/utils/authUtils';

const AVATAR_CACHE_KEY = 'user_avatar_cache';
const USERNAME_CACHE_KEY = 'user_username_cache';

export function ProfileButton() {
  const walletAddress = getWalletAddress();
  const { profile, loading } = useUserProfile(walletAddress);

  // Load cached avatar immediately to prevent flash
  const [cachedAvatar, setCachedAvatar] = useState<string | null>(() => {
    try {
      return localStorage.getItem(AVATAR_CACHE_KEY);
    } catch {
      return null;
    }
  });

  const [cachedUsername, setCachedUsername] = useState<string>(() => {
    try {
      return localStorage.getItem(USERNAME_CACHE_KEY) || 'User';
    } catch {
      return 'User';
    }
  });

  // Local override so we can update immediately on avatar change events
  const [avatarOverride, setAvatarOverride] = useState<string | null>(null);

  // Cache the avatar URL whenever profile loads or changes
  useEffect(() => {
    if (profile?.avatar_url) {
      try {
        localStorage.setItem(AVATAR_CACHE_KEY, profile.avatar_url);
        setCachedAvatar(profile.avatar_url);
      } catch (error) {
        console.error('Failed to cache avatar:', error);
      }
    }

    const displayName = profile?.display_name || profile?.username;
    if (displayName) {
      try {
        localStorage.setItem(USERNAME_CACHE_KEY, displayName);
        setCachedUsername(displayName);
      } catch (error) {
        console.error('Failed to cache username:', error);
      }
    }
  }, [profile?.avatar_url, profile?.display_name, profile?.username]);

  useEffect(() => {
    const handler = (e: Event) => {
      const detail = (e as CustomEvent).detail as { avatarUrl?: string } | undefined;
      if (detail?.avatarUrl) {
        setAvatarOverride(detail.avatarUrl);
        // Update cache immediately
        try {
          localStorage.setItem(AVATAR_CACHE_KEY, detail.avatarUrl);
          setCachedAvatar(detail.avatarUrl);
        } catch (error) {
          console.error('Failed to cache avatar on change:', error);
        }
      }
    };

    window.addEventListener('avatar-changed', handler as EventListener);
    return () => {
      window.removeEventListener('avatar-changed', handler as EventListener);
    };
  }, []);

  const username = profile?.display_name || profile?.username || cachedUsername || 'User';
  const avatar = avatarOverride || profile?.avatar_url || cachedAvatar || '/profilepictures/profileimg1.jpg';

  return <Button variant="ghost" size="icon" className="rounded-full p-0 h-10 w-10 ring-1 ring-white/20 hover:ring-white/40 transition-all" type="button" aria-label="Open profile menu">
      <Avatar>
        <AvatarImage alt="Profile" src={avatar} />
        <AvatarFallback>{username.slice(0, 2).toUpperCase()}</AvatarFallback>
      </Avatar>
    </Button>;
}
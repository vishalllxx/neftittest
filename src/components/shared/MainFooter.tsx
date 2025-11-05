import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Link } from "react-router-dom";
import { Twitter, MessageSquare, Send, Linkedin } from "lucide-react"; // social icons

export function MainFooter() {
  return (
    <footer className="relative">
      {/* Main Footer  */}
      <div className="bg-[#0b0a14] border-t border-[#2b284b]">
        <div className="mx-auto w-full max-w-7xl px-4 sm:px-6 py-12">
        <div className="flex flex-col md:flex-row md:justify-between md:items-start gap-8 md:gap-44">
          {/* Brand Section */}
          <div className="md:w-2/4">
            <div className="space-y-4">
              <h2 className="text-xl md:text-2xl font-bold tracking-tighter text-white flex items-center justify-start">
                <img src="/icons/NEFTIT FAVICON.png" alt="NEFTIT" className="w-6 h-6 md:w-8 md:h-8 mr-2" />
                NEFTIT
              </h2>
              <p className="text-sm text-gray-400">
              NEFTIT is a Web3 engagement platform designed to empower NFT projects<br />       
              and communities through gamified interactions.
              </p>
            </div>
          </div>

          {/* Links Section */}
          <div className="flex flex-1 justify-between md:justify-between lg:justify-between md:gap-8 lg:gap-4">
            {/* Company Links */}
            <div>
              <h3 className="text-sm lg:text-lg md:text-sm font-semibold text-white mb-2">COMPANY</h3>
              <div className="flex flex-col gap-2">
                <Link to="/docs/general/about_us" className="text-[10px] lg:text-sm md:text-[10px] text-gray-400 hover:text-[#5D43EF]">About Us</Link>
                <Link to="/docs/appendix/contact-links" className="text-[10px] lg:text-sm md:text-[10px] text-gray-400 hover:text-[#5D43EF]">Contact Us</Link>
                {/*<Link to="/partnership" className="text-[10px] lg:text-sm md:text-[10px] text-gray-400 hover:text-[#5D43EF]">Partnership</Link>*/}
              </div>
            </div>

            {/* Support Section*/}
            <div>
              <h3 className="text-sm lg:text-lg md:text-sm font-semibold text-white mb-2">SUPPORT</h3>
              <div className="flex flex-col gap-2">
                <Link to="/docs/overview" className="text-[10px] lg:text-sm md:text-[10px] text-gray-400 hover:text-[#5D43EF]">Docs</Link>
                <Link to="/docs/appendix/media-kit" className="text-[10px] lg:text-sm md:text-[10px] text-gray-400 hover:text-[#5D43EF]">Media Kit</Link>
                <Link to="/docs/legal-compliance-risk/privacy-policy" className="text-[10px] lg:text-sm md:text-[10px] text-gray-400 hover:text-[#5D43EF]">Privacy Policy</Link>
                <Link to="/docs/legal-compliance-risk/terms-of-service" className="text-[10px] lg:text-sm md:text-[10px] text-gray-400 hover:text-[#5D43EF]">Terms of Service</Link>
              </div>
            </div>

            {/* Social Section */}
            <div>
              <h3 className="text-sm lg:text-lg md:text-sm font-semibold text-white mb-2">SOCIAL</h3>
              <div className="flex flex-col gap-3">
                <a href="https://x.com/neftitxyz" target="_blank" rel="noopener noreferrer" className="text-gray-400 hover:text-[#5D43EF] flex items-center transition-colors duration-200">
                  <img src="/icons/x-social-media-round-icon.png" alt="Twitter" className="w-4 h-4 md:w-5 md:h-5" />
                  <span className="ml-2 text-[10px] lg:text-sm md:text-[10px]">Twitter</span>
                </a>
                <a href="https://discord.gg/neftit" target="_blank" rel="noopener noreferrer" className="text-gray-400 hover:text-[#5D43EF] flex items-center transition-colors duration-200">
                  <img src="/icons/discord-round-color-icon.png" alt="Discord" className="w-4 h-4 md:w-5 md:h-5" />
                  <span className="ml-2 text-[10px] lg:text-sm md:text-[10px]">Discord</span>
                </a>
                <a href="#" target="_blank" rel="noopener noreferrer" className="text-gray-400 hover:text-[#5D43EF] flex items-center transition-colors duration-200">
                  <img src="/icons/telegram-icon.png" alt="Telegram" className="w-4 h-4 md:w-5 md:h-5" />
                  <span className="ml-2 text-[10px] lg:text-sm md:text-[10px]">Telegram</span>
                </a>
                <a href="#" target="_blank" rel="noopener noreferrer" className="text-gray-400 hover:text-[#5D43EF] flex items-center transition-colors duration-200">
                  <img src="/icons/linkedin_icon.png" alt="LinkedIn" className="w-4 h-4 md:w-5 md:h-5" />
                  <span className="ml-2 text-[10px] lg:text-sm md:text-[10px]">LinkedIn</span>
                </a>
              </div>
            </div>
          </div>
        </div>


          {/* Bottom Bar */}
          <div className="mt-8 sm:mt-4 md:mt-8 lg:mt-12 pt-2 border-t border-[#2b284b] text-left text-sm text-gray-400">
            <p className="text-[10px] lg:text-sm md:text-[10px]">© {new Date().getFullYear()} NEFTIT | <span>All Rights Reserved</span></p>
          </div>

          {/* Logo at bottom */}
          <div className="w-full flex justify-center mt-6">
            <img 
              src="/images/neftitFont.png" 
              alt="NEFTIT" 
              className="opacity-70"
              style={{
                maskImage: 'linear-gradient(to bottom, rgba(0,0,0,0.7) 0%, rgba(0,0,0,0) 100%)',
                WebkitMaskImage: 'linear-gradient(to bottom, rgba(0,0,0,0.7) 0%, rgba(0,0,0,0) 100%)',
                WebkitMaskSize: '100%',
                maskSize: '100%',
                WebkitMaskPosition: 'top',
                maskPosition: 'top'
              }}
            />
          </div>
        </div>
      </div>
    </footer>
  );
}

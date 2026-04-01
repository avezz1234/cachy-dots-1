{ pkgs, config, lib, ... }:

{
   home.packages = with pkgs; [
       pkgs.swaynotificationcenter
   ];

   xdg.configFile."swaync".source = config.lib.file.mkOutOfStoreSymlink "/etc/nixos/config/programs/swaync";
}

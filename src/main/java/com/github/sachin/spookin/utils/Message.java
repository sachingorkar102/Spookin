package com.github.sachin.spookin.utils;


import com.github.sachin.spookin.Spookin;

import org.bukkit.ChatColor;
import org.bukkit.configuration.file.FileConfiguration;

public class Message {


    private final FileConfiguration CONFIG;
    private final Spookin plugin = Spookin.getPlugin();

    public Message(){
        CONFIG = plugin.getConfigFromFile("messages.yml");
    }


    public String getMessage(String key){
        return ChatColor.translateAlternateColorCodes('&', CONFIG.getString("prefix","")+CONFIG.getString(key,""));
    }

    public String getMessageWithoutPrefix(String key){
        return ChatColor.translateAlternateColorCodes('&', CONFIG.getString(key,""));
    }
    
}

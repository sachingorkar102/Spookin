package com.github.sachin.spookin.modules.curses;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import com.github.sachin.spookin.Spookin;

import org.bukkit.ChatColor;
import org.bukkit.Material;
import org.bukkit.NamespacedKey;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerBedEnterEvent;
import org.bukkit.event.player.PlayerBedEnterEvent.BedEnterResult;
import org.bukkit.persistence.PersistentDataType;

public class SleepCurse extends BaseCurse implements Listener{

    public final List<String> sleepMessages = new ArrayList<>();

    public SleepCurse(CurseModule instance) {
        super("&eSleep", "sleep", Arrays.asList("&7Dosn't allow you to sleep"), Spookin.getKey("sleep-curse-key"),Arrays.asList(Material.PHANTOM_MEMBRANE,Material.SPIDER_EYE), instance);
        sleepMessages.add(ChatColor.translateAlternateColorCodes('&', "&cYou don't feel tired enough to sleep."));
        sleepMessages.add(ChatColor.translateAlternateColorCodes('&', "&cIts not correct time to sleep."));
        sleepMessages.add(ChatColor.translateAlternateColorCodes('&', "&cGamers don't sleep!"));
        sleepMessages.add(ChatColor.translateAlternateColorCodes('&', "&cYou slept last night, right??"));
        sleepMessages.add(ChatColor.translateAlternateColorCodes('&', "&cDont't you want to watch that one series on TV?"));
        sleepMessages.add(ChatColor.translateAlternateColorCodes('&', "&cRemember, sleep is the cousin of death"));
        sleepMessages.add(ChatColor.translateAlternateColorCodes('&', "&cCheck again in which dimension you are in.."));
    }
 
    
    @EventHandler
    public void onSleep(PlayerBedEnterEvent e){
        if(e.getPlayer().getPersistentDataContainer().has(curseKey, PersistentDataType.STRING) && e.getBedEnterResult() == BedEnterResult.OK){
            e.setCancelled(true);
            e.getPlayer().sendMessage(sleepMessages.get(RANDOM.nextInt(sleepMessages.size())));
        }
    }
}

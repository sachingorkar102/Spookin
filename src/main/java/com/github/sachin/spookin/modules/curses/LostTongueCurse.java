package com.github.sachin.spookin.modules.curses;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import com.github.sachin.spookin.Spookin;
import com.google.common.primitives.Chars;

import org.bukkit.Material;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.AsyncPlayerChatEvent;
import org.bukkit.inventory.ItemStack;
import org.bukkit.persistence.PersistentDataType;

public class LostTongueCurse extends BaseCurse implements Listener{


    public LostTongueCurse(CurseModule instance) {
        super("&eLost Tongue","lost_tongue",Arrays.asList("&7Anything you type in chat turns into gibbresh"),Spookin.getKey("lost-tongue-curse"), Arrays.asList(Material.HONEYCOMB,Material.SLIME_BALL), instance);
    }


    @EventHandler
    public void onChat(AsyncPlayerChatEvent e){
        Player player = e.getPlayer();
        if(player.getPersistentDataContainer().has(curseKey,PersistentDataType.STRING)){
            List<Character> chars = Chars.asList(e.getMessage().toCharArray());
            Collections.shuffle(chars);
            String shuffledMessage = new String(Chars.toArray(chars));
            e.setMessage(shuffledMessage);
        }
    }

}

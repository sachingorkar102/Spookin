package com.github.sachin.spookin.modules.curses;

import java.util.Arrays;

import com.github.sachin.spookin.Spookin;

import org.bukkit.Bukkit;
import org.bukkit.Material;
import org.bukkit.Sound;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.scheduler.BukkitRunnable;

public class SlipperyHandsCurse extends BaseCurse{

    public SlipperyHandsCurse(CurseModule instance) {
        super("&eSlippery Hands","slippery_hands",Arrays.asList("&7Randomly drops item you are holding"),Spookin.getKey("slippery-hands-curse-key"),Arrays.asList(Material.HONEY_BOTTLE,Material.SLIME_BALL), instance);
        new BukkitRunnable(){
            @Override
            public void run() {
                for(Player player : Bukkit.getOnlinePlayers()){
                    if(player.getPersistentDataContainer().has(curseKey, PersistentDataType.STRING) && RANDOM.nextInt(50) > 2){
                        ItemStack mainhand = player.getInventory().getItemInMainHand();
                        ItemStack offhand = player.getInventory().getItemInOffHand();
                        boolean itemdroped = false;
                        if(RANDOM.nextInt(2)==1 && mainhand != null && !mainhand.getType().isAir()){
                            player.getWorld().dropItemNaturally(player.getLocation(), mainhand);
                            player.getInventory().setItemInMainHand(null);
                            itemdroped = true;
                        }
                        else if(offhand != null && !offhand.getType().isAir()){
                            player.getWorld().dropItemNaturally(player.getLocation(), offhand);
                            player.getInventory().setItemInOffHand(null);
                            itemdroped = true;
                        }

                        if(itemdroped){
                            player.getWorld().playSound(player.getLocation(), Sound.ENTITY_PLAYER_BIG_FALL, 2F, RANDOM.nextFloat() * 0.4F + 0.8F);
                        }
                    }
                }
            }
        }.runTaskTimer(instance.getPlugin(),0, 100);
    }
    
}

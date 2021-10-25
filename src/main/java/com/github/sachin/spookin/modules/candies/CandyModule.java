package com.github.sachin.spookin.modules.candies;

import com.github.sachin.spookin.BaseModule;
import com.github.sachin.spookin.manager.Module;
import com.github.sachin.spookin.nbtapi.NBTItem;
import com.github.sachin.spookin.utils.Advancements;
import com.github.sachin.spookin.utils.Items;
import com.github.sachin.spookin.utils.SConstants;

import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerInteractEvent;
import org.bukkit.event.player.PlayerItemConsumeEvent;
import org.bukkit.inventory.ItemStack;
import org.bukkit.potion.PotionEffect;
import org.bukkit.potion.PotionEffectType;

@Module(name= "candies")
public class CandyModule extends BaseModule implements Listener{



    


    @EventHandler
    public void onEat(PlayerItemConsumeEvent e){
        if(e.getItem() == null) return;
        ItemStack item = e.getItem();
        if(Items.hasKey(item, SConstants.CANDY_BAR_KEY) || Items.hasKey(item,SConstants.CANDY_KEY) || Items.hasKey(item,SConstants.SWIRLY_PO_KEY)){
            
            Player player = e.getPlayer();
            if(Items.hasKey(item, SConstants.SWIRLY_PO_KEY)){
                Advancements.awardCriteria("candies","pop",player);
                player.addPotionEffect(new PotionEffect(PotionEffectType.FAST_DIGGING,30*20,3));
            }
            else if(Items.hasKey(item, SConstants.CANDY_KEY)){
                Advancements.awardCriteria("candies","candy",player);
                player.addPotionEffect(new PotionEffect(PotionEffectType.REGENERATION,30*20,2));
            }
            else if(Items.hasKey(item, SConstants.CANDY_BAR_KEY)){
                Advancements.awardCriteria("candies","candy-bar",player);
                player.addPotionEffect(new PotionEffect(PotionEffectType.INCREASE_DAMAGE,30*20,2));
            }
        }
    }


    @EventHandler
    public void onRightClick(PlayerInteractEvent e){
        if(e.getItem() == null) return;
        ItemStack item = e.getItem();
        if(Items.hasKey(item, SConstants.CANDY_BAR_KEY) || Items.hasKey(item,SConstants.CANDY_KEY) || Items.hasKey(item,SConstants.SWIRLY_PO_KEY)){
            e.getPlayer().setFoodLevel(19);

        }
    }
    
}

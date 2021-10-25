package com.github.sachin.spookin.utils;


import com.github.sachin.spookin.Spookin;

import org.bukkit.Bukkit;
import org.bukkit.NamespacedKey;
import org.bukkit.advancement.Advancement;
import org.bukkit.craftbukkit.v1_17_R1.advancement.CraftAdvancement;
import org.bukkit.craftbukkit.v1_17_R1.entity.CraftPlayer;
import org.bukkit.entity.Player;

import io.papermc.paper.datapack.Datapack;
import net.minecraft.server.level.EntityPlayer;

public class Advancements {


    public static boolean isEnabled;

    static{
        isEnabled = false;
        for(Datapack d : Spookin.getPlugin().getServer().getDatapackManager().getEnabledPacks()){
            if(d.getName().contains("spookin_datapack")){
                Spookin.getPlugin().getLogger().info("Running advancement datapack....");
                isEnabled = true;
            }
        }
    }


    public static void awardAdvancement(String name,Player player) {
        if(isEnabled){
            Advancement ad = Bukkit.getAdvancement(NamespacedKey.fromString("spookin:"+name));
            if(ad != null && !player.getAdvancementProgress(ad).isDone()){
                EntityPlayer nmsPlayer = ((CraftPlayer)player).getHandle();
                award(nmsPlayer,((CraftAdvancement)ad).getHandle());
            }
        }
       
       
    }

    public static void awardCriteria(String name,String cri,Player player){
        if(isEnabled){
            Advancement ad = Bukkit.getAdvancement(NamespacedKey.fromString("spookin:"+name));
            if(ad != null && !player.getAdvancementProgress(ad).isDone()){
                EntityPlayer nmsPlayer = ((CraftPlayer)player).getHandle();
                net.minecraft.advancements.Advancement advance = ((CraftAdvancement)ad).getHandle();
                net.minecraft.advancements.AdvancementProgress var2 = nmsPlayer.getAdvancementData().getProgress(advance);
                if(!var2.isDone()){
                    for (String var4 : var2.getRemainingCriteria()){
                        if(var4.equals(cri)){
                            nmsPlayer.getAdvancementData().grantCriteria(advance, var4);
                        }
                    }
                }
            }
        }
    }

    public static boolean award(EntityPlayer var0, net.minecraft.advancements.Advancement var1) {
        net.minecraft.advancements.AdvancementProgress var2 = var0.getAdvancementData().getProgress(var1);
        if (var2.isDone())
          return false; 
        for (String var4 : var2.getRemainingCriteria())
          var0.getAdvancementData().grantCriteria(var1, var4); 
        return true;
    }
    
}

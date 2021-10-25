package com.github.sachin.spookin.commands;


import java.util.ArrayList;
import java.util.Arrays;
import java.util.function.Predicate;

import com.github.sachin.spookin.BaseItem;
import com.github.sachin.spookin.modules.trickortreatbasket.TrickOrTreatBasketModule;
import com.github.sachin.spookin.utils.SConstants;
import com.google.common.base.Predicates;
import com.mojang.datafixers.types.templates.List;

import org.bukkit.Bukkit;
import org.bukkit.Location;
import org.bukkit.Particle;
import org.bukkit.craftbukkit.v1_17_R1.entity.CraftPlayer;
import org.bukkit.entity.ArmorStand;
import org.bukkit.entity.Entity;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;
import org.bukkit.util.EulerAngle;

import net.minecraft.server.level.EntityPlayer;
import net.minecraft.world.entity.monster.EntitySlime;

public class GiveCommand extends SubCommand{

    public GiveCommand() {
        super("Gives player speficed spookin item", "give", "spookin.command.give", "/spookin give [player-name] [item-type] [amount]");
        addCompletion(2, null);
        addCompletion(3, Arrays.asList("scarecrow","dagger","monsterbox","trick-or-treat-basket","random-trick-or-treat-basket",SConstants.SWIRLY_PO_KEY,SConstants.CANDY_BAR_KEY,SConstants.CANDY_KEY,SConstants.LAUNCHER_KEY));
    }

    @Override
    public void execute(Player player, String[] args) {
        if(args.length < 3) return;
        int amount = 1;
        if(args.length > 3){
            amount = Integer.parseInt(args[3]);
        }
        String name = args[2];
        Player target = Bukkit.getPlayer(args[1]);
        if(target != null && target.isOnline()){
            ItemStack item = null;
            if(name.equals("random-trick-or-treat-basket")){
                TrickOrTreatBasketModule module = (TrickOrTreatBasketModule) plugin.getModuleManager().getModuleFromName("trick-or-treat-basket");
                for(int i = 0;i<amount;i++){
    
                    target.getInventory().addItem(module.getRandomizedBasket());
                }
                return;
            }
            else if(name.equals("scarecrow") || name.equals("monsterbox") || name.equals("trick-or-treat-basket")){
                BaseItem module = (BaseItem) plugin.getModuleManager().getModuleFromName(name);
                if(module != null){
                    for(int i = 0;i<amount;i++){
    
                        target.getInventory().addItem(module.getItem());
                    }
                    return;
                }
            }
            else if(name.equals("dagger")){
                item = plugin.getItemFolder().DAGGER.clone();
            }
            else if(name.equals(SConstants.SWIRLY_PO_KEY)){
                item = plugin.getItemFolder().SWIRLY_POP.clone();
            }
            else if(name.equals(SConstants.CANDY_KEY)){
                item = plugin.getItemFolder().CANDY.clone();
            }
            else if(name.equals(SConstants.CANDY_BAR_KEY)){
                item = plugin.getItemFolder().CANDY_BAR.clone();
            }
            else if(name.equals(SConstants.LAUNCHER_KEY)){
                item = plugin.getItemFolder().JACKOLAUNCHER.clone();
            }
    
            if(item != null){
                for(int i = 0;i<amount;i++){
    
                    target.getInventory().addItem(item);
                }
            }

        }
    }
    
}

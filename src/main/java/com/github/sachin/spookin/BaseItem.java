package com.github.sachin.spookin;

import com.github.sachin.spookin.nbtapi.NBTItem;
import com.github.sachin.spookin.utils.ItemBuilder;

import org.bukkit.inventory.ItemStack;

public class BaseItem extends BaseModule{

    protected ItemStack item;

    @Override
    public void reload() {
        super.reload();
        this.item = ItemBuilder.getItemFromConfig(plugin.getItemFolder().CONFIG.getConfigurationSection(getName()),getName());
    }


    public boolean isSimilar(ItemStack item){
        if(item == null) return false;
        NBTItem nbti = new NBTItem(item);
        if(nbti.hasKey("spookin-item")){
            return nbti.getString("spookin-item").equals(getName());
        }
        return false;
    }

    public ItemStack getItem() {
        return item;
    }
    
    
}

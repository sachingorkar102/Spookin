package com.github.sachin.spookin.utils;

import com.github.sachin.spookin.Spookin;
import com.github.sachin.spookin.nbtapi.NBTItem;

import org.bukkit.Material;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;

public class Items {

    public final FileConfiguration CONFIG;
    public final ItemStack DAGGER;
    public final ItemStack IMBUED_DAGGER;
    public final ItemStack SWIRLY_POP;
    public final ItemStack CANDY;
    public final ItemStack CANDY_BAR;
    public final ItemStack WITCH_HAT;
    public final ItemStack JACKOLAUNCHER;
    public final ItemStack LAUNCHER_AMMO;
    public final ItemStack LAUNCHER_ENTITY;

    public Items(Spookin plugin){
        this.CONFIG = plugin.getConfigFromFile("items.yml");
        this.DAGGER = ItemBuilder.getItemFromConfig(CONFIG.getConfigurationSection("dagger"), "dagger");
        this.IMBUED_DAGGER = ItemBuilder.getItemFromConfig(CONFIG.getConfigurationSection("imbued-dagger"), "imbued-dagger");
        this.SWIRLY_POP = ItemBuilder.getItemFromConfig(CONFIG.getConfigurationSection("swirly-pop"), "swirly-pop");
        this.CANDY = ItemBuilder.getItemFromConfig(CONFIG.getConfigurationSection("candy"),"candy");
        this.CANDY_BAR = ItemBuilder.getItemFromConfig(CONFIG.getConfigurationSection("candy-bar"), "candy-bar");
        this.WITCH_HAT = ItemBuilder.getItemFromConfig(CONFIG.getConfigurationSection("witch-hat"), "witch-hat");
        this.JACKOLAUNCHER = ItemBuilder.getItemFromConfig(CONFIG.getConfigurationSection("jack-o-launcher"), "jack-o-launcher");
        this.LAUNCHER_AMMO = ItemBuilder.getItemFromConfig(CONFIG.getConfigurationSection("launcher-ammo"), "launcher-ammo");
        this.LAUNCHER_ENTITY = new ItemStack(Material.SWEET_BERRIES);
        ItemMeta meta = LAUNCHER_ENTITY.getItemMeta();
        meta.setCustomModelData(7);
        LAUNCHER_ENTITY.setItemMeta(meta);
    }


    public static boolean hasKey(ItemStack item,String key){
        if(item != null){
            NBTItem nbti = new NBTItem(item);
            return nbti.hasKey("spookin-item") && nbti.getString("spookin-item").equals(key);
        }
        return false;
    }
    
}

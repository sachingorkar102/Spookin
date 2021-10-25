package com.github.sachin.spookin.modules.jackolauncher;

import com.github.sachin.spookin.nbtapi.NBTItem;
import com.github.sachin.spookin.utils.InventoryUtils;
import com.github.sachin.spookin.utils.SConstants;

import org.bukkit.inventory.ItemStack;

public class ProjectileHelper {


    public ItemStack ammo;
    public boolean isMuffled =false;
    public boolean isEnderpearl = false;
    public boolean hasFireCharge = false;
    public boolean hasSilkTouch = false;
    public boolean applyBoneMeal = false;
    public int fortuneLevel = 0;
    public ItemStack fireWork;
    public ItemStack splashPotion;
    public ItemStack lingeringPotion;
    public int yeild = 0;
    public ItemStack potion;
    
    

    public ProjectileHelper(ItemStack ammo){
        this.ammo = ammo;
        NBTItem nbti = new NBTItem(ammo);
        this.yeild = nbti.hasKey(SConstants.YEILD_KEY) ? nbti.getInt(SConstants.YEILD_KEY) : 1;
        this.isMuffled = nbti.hasKey(SConstants.MUFFLED_KEY) ? nbti.getBoolean(SConstants.MUFFLED_KEY) : false;
        this.fireWork = nbti.hasKey(SConstants.FIREWORK_KEY) ? InventoryUtils.deserializeItem(nbti.getString(SConstants.FIREWORK_KEY)) : null;
        this.isEnderpearl = nbti.hasKey(SConstants.ENDERPEARL_KEY) ? nbti.getBoolean(SConstants.ENDERPEARL_KEY) : false;
        this.hasFireCharge = nbti.hasKey(SConstants.FIRECHARGE_KEY) ? nbti.getBoolean(SConstants.FIRECHARGE_KEY) : false;
        this.hasSilkTouch = nbti.hasKey(SConstants.SILKTOUCH_KEY) ? nbti.getBoolean(SConstants.SILKTOUCH_KEY) : false;
        this.fortuneLevel = nbti.hasKey(SConstants.FORTUNE_KEY) ? nbti.getInt(SConstants.FORTUNE_KEY) : 0;
        this.applyBoneMeal = nbti.hasKey(SConstants.BONEMEAL_KEY) ? nbti.getBoolean(SConstants.BONEMEAL_KEY) : false;
        this.splashPotion = nbti.hasKey(SConstants.POTION_KEY) ? InventoryUtils.deserializeItem(nbti.getString(SConstants.POTION_KEY)) : null;
        this.lingeringPotion = nbti.hasKey(SConstants.LINGERING_KEY) ? InventoryUtils.deserializeItem(nbti.getString(SConstants.LINGERING_KEY)) : null;
        this.potion = nbti.hasKey(SConstants.POTION_KEY) ? InventoryUtils.deserializeItem(nbti.getString(SConstants.POTION_KEY)) : null;
    }
    
}

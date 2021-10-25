package com.github.sachin.spookin.nbtapi.nms;

import org.bukkit.Location;
import org.bukkit.NamespacedKey;
import org.bukkit.entity.Animals;
import org.bukkit.entity.Entity;
import org.bukkit.inventory.ItemStack;


public abstract class NMSHelper {


    public abstract NMSHelper newItem(ItemStack item);

    
    
    public abstract void setString(String key,String value);
    public abstract void setBoolean(String key,boolean value);
    public abstract void setInt(String key,int value);
    public abstract void setLong(String key,long value);
    public abstract void setDouble(String key,double value);
    
    
    public abstract String getString(String key);
    public abstract boolean getBoolean(String key);
    public abstract int getInt(String key);
    public abstract long getLong(String key);
    public abstract double getDouble(String key);
    
    
    public abstract boolean hasKey(String key);
    
    public abstract ItemStack getItem();
    
    public abstract void removeKey(String key);


    public void addGoal(Animals en,NamespacedKey cursedkey){

    }

    public void addFleeGoal(Entity en){}

    public void summonSkeleHead(Location loc){}

}

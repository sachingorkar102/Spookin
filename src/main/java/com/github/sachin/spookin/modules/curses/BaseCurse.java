package com.github.sachin.spookin.modules.curses;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Random;
import java.util.UUID;
import java.util.stream.Collectors;

import com.github.sachin.spookin.Spookin;
import com.github.sachin.spookin.nbtapi.NBTItem;
import com.github.sachin.spookin.utils.Advancements;

import org.bukkit.Bukkit;
import org.bukkit.ChatColor;
import org.bukkit.Material;
import org.bukkit.NamespacedKey;
import org.bukkit.entity.Player;
import org.bukkit.event.Listener;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.persistence.PersistentDataType;

public abstract class BaseCurse {


    public final String name;
    public final String id;
    public final CurseModule instance;
    public final List<Material> ingredients;
    public final ItemStack book;
    public final NamespacedKey curseKey;
    public final Random RANDOM = Spookin.getPlugin().RANDOM;


    public BaseCurse(String name ,String id,List<String> lore,NamespacedKey curseKey,List<Material> ingredients,CurseModule instance){
        this.name = name;
        this.id = id;
        this.instance = instance;
        this.ingredients = ingredients;
        this.curseKey = curseKey;
        ItemStack b = new ItemStack(Material.ENCHANTED_BOOK);
        ItemMeta meta = b.getItemMeta();
        meta.setDisplayName(ChatColor.translateAlternateColorCodes('&', name));
        lore = lore.stream().map(s-> ChatColor.translateAlternateColorCodes('&', s)).collect(Collectors.toList());
        meta.setLore(lore);
        b.setItemMeta(meta);
        NBTItem nbti = new NBTItem(b);
        nbti.setString("curse-book",name);
        this.book = nbti.getItem();

        if(this instanceof Listener ){
            instance.registerEvents(((Listener)this));
        }
    }


    public ItemStack bindBook(Player player){
        ItemStack bindedBook = book.clone();

        List<String> extraLore = new ArrayList<>();
        extraLore.add(ChatColor.GRAY+"Binded to: "+ChatColor.GREEN+player.getName());
        extraLore.add(ChatColor.GRAY+"Throw on Soul Campfire to apply the curse");
        ItemMeta meta = bindedBook.getItemMeta();
        if(meta.hasLore()){
            extraLore.addAll(meta.getLore());
        }
        meta.setLore(extraLore);
        bindedBook.setItemMeta(meta);
        NBTItem nbti = new NBTItem(bindedBook);
        nbti.setString("binded-player", player.getUniqueId().toString());
        return nbti.getItem();
    }

    public void applyCurse(Player player){
        player.getPersistentDataContainer().set(curseKey, PersistentDataType.STRING, "");
        Advancements.awardAdvancement(id, player);
    };
    

    public Player getPlayer(ItemStack item){
        NBTItem nbti = new NBTItem(item);
        Player player = Bukkit.getPlayer(UUID.fromString(nbti.getString("binded-player")));
        if(player != null && player.isOnline()){
            return player;
        }
        return null;
    }

    public void onRemove(Player player){

    }

}

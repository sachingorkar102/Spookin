package com.github.sachin.spookin.modules.curses;

import java.util.Arrays;
import java.util.List;

import com.github.sachin.spookin.Spookin;

import org.bukkit.Material;
import org.bukkit.NamespacedKey;
import org.bukkit.entity.Animals;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.entity.EntitySpawnEvent;

public class AnimalFearCurse extends BaseCurse implements Listener{

    public AnimalFearCurse(CurseModule instance) {
        super("&eAnimal Fear", "animal_fear", Arrays.asList("&7Will cause animals to run away from you"),Spookin.getKey("animal-fear-key"),Arrays.asList(Material.ROTTEN_FLESH,Material.REDSTONE), instance);
    }



    @EventHandler
    public void onSpawn(EntitySpawnEvent e){
        if(e.getEntity() instanceof Animals){
            instance.getPlugin().getNmsHelper().addGoal((Animals)e.getEntity(), curseKey);
        }
    }
}

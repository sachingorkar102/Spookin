package com.github.sachin.spookin.commands;

import java.util.Collection;
import java.util.HashSet;
import java.util.Set;
import java.util.TreeMap;

import com.github.sachin.spookin.modules.monsterbox.MonsterBoxModule;
import com.github.sachin.spookin.utils.SConstants;

import org.bukkit.ChatColor;
import org.bukkit.Chunk;
import org.bukkit.Location;
import org.bukkit.World;
import org.bukkit.block.BlockState;
import org.bukkit.block.CreatureSpawner;
import org.bukkit.entity.Player;
import org.bukkit.persistence.PersistentDataType;

public class SearchCommand extends SubCommand{

    public SearchCommand() {
        super("Searches for monster box in nearby loaded chunks", "searchbox", "spookin.command.searchbox", "/spookin searchbox");
    }
    

    @Override
    public void execute(Player player, String[] args) {
        TreeMap<Double,Location> map = new TreeMap<>();
        for(Location loc : MonsterBoxModule.boxes){
            if(loc.getWorld().equals(player.getWorld())){
                map.put(loc.distanceSquared(player.getLocation()), loc);
            }
        }
        if(!map.isEmpty()){
            Location loc = map.firstEntry().getValue();
            player.sendMessage(ChatColor.translateAlternateColorCodes('&', "&eNearest Monster Box is located at: &a"+loc.getBlockX()+","+loc.getBlockY()+","+loc.getBlockZ()));
        }
        else{
            player.sendMessage(ChatColor.RED+"Could not locate any monster box nearby, generate new chunks and then re-run the command");
        }
    }


    public Collection<Chunk> around(Chunk origin, int radius) {
        World world = origin.getWorld();
    
        int length = (radius * 2) + 1;
        Set<Chunk> chunks = new HashSet<>(length * length);
    
        int cX = origin.getX();
        int cZ = origin.getZ();
    
        for (int x = -radius; x <= radius; x++) {
            for (int z = -radius; z <= radius; z++) {
                Chunk c = world.getChunkAt(cX + x, cZ + z);
                if(c.isLoaded()){
                    chunks.add(world.getChunkAt(cX + x, cZ + z));
                }
            }
        }
        return chunks;
    }
}

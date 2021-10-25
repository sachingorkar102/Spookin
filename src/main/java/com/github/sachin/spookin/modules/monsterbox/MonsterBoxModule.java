package com.github.sachin.spookin.modules.monsterbox;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ThreadLocalRandom;
import java.util.stream.Collectors;

import com.github.sachin.spookin.BaseItem;
import com.github.sachin.spookin.manager.Module;
import com.github.sachin.spookin.modules.trickortreatbasket.TrickOrTreatBasketModule;
import com.github.sachin.spookin.utils.Advancements;
import com.github.sachin.spookin.utils.SConstants;

import org.bukkit.Bukkit;
import org.bukkit.Chunk;
import org.bukkit.GameMode;
import org.bukkit.Location;
import org.bukkit.Material;
import org.bukkit.Particle;
import org.bukkit.Sound;
import org.bukkit.World;
import org.bukkit.World.Environment;
import org.bukkit.block.Block;
import org.bukkit.block.BlockFace;
import org.bukkit.block.BlockState;
import org.bukkit.block.CreatureSpawner;
import org.bukkit.entity.CaveSpider;
import org.bukkit.entity.Entity;
import org.bukkit.entity.EntityType;
import org.bukkit.entity.LivingEntity;
import org.bukkit.entity.Player;
import org.bukkit.entity.Spider;
import org.bukkit.entity.WanderingTrader;
import org.bukkit.entity.Witch;
import org.bukkit.entity.Zombie;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.block.Action;
import org.bukkit.event.player.PlayerInteractEvent;
import org.bukkit.event.server.ServerLoadEvent;
import org.bukkit.event.server.ServerLoadEvent.LoadType;
import org.bukkit.event.world.ChunkLoadEvent;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.scheduler.BukkitRunnable;
import org.bukkit.util.Vector;

@Module(name = "monsterbox")
public class MonsterBoxModule extends BaseItem implements Listener{


    public static final Set<Location> boxes = new HashSet<>();

    public MonsterBoxModule(){
        super();
        BoxRunnable runnable = new BoxRunnable();
        runnable.runTaskTimer(plugin, 0, 20);
    }

    @EventHandler
    public void onInteract(PlayerInteractEvent e){
        if(isSimilar(e.getItem()) && e.getAction()==Action.RIGHT_CLICK_BLOCK){
            e.setCancelled(true);
            spawnMonsterBox(e.getClickedBlock().getRelative(e.getBlockFace()));
        }
    }

    
    @EventHandler
    public void onChunkLoad(ChunkLoadEvent e){
        Chunk chunk = e.getChunk();
        if(chunk.getWorld().getEnvironment()!=Environment.NORMAL) return;
        if(e.isNewChunk()){
            Location loc = chunk.getBlock(plugin.RANDOM.nextInt(8), 0, plugin.RANDOM.nextInt(8)).getLocation();
            
            for(int i =0; i<5;i++){
                loc.setY(ThreadLocalRandom.current().nextInt(10, 40));
                Block block = loc.getBlock();

                if(plugin.RANDOM.nextInt(35) < 5 && block.getType().isAir() && block.getRelative(BlockFace.DOWN).getType().isSolid() && block.getRelative(BlockFace.UP).getType().isAir()){
                    spawnMonsterBox(block);
                    block.getRelative(BlockFace.DOWN).setType(Material.GLOWSTONE);
                }
            }
        }
        else{
            reAddBox(chunk);
            new BukkitRunnable() {
                @Override
                public void run() {
                    if(!chunk.isLoaded()) return;
                    for(Entity en : chunk.getEntities()){
                        if(en instanceof WanderingTrader){
                            TrickOrTreatBasketModule.entityIdMap.put(en.getEntityId(),en.getUniqueId());
                        }
                    }
                }
            }.runTaskLater(plugin, 7);
        }
    }

    // /give @p minecraft:player_head{display:{Name:"{\"text\":\"Carved Pumpkin\"}"},SkullOwner:{Id:[I;173865172,-694859405,-1825278953,-678921121],Properties:{textures:[{Value:"eyJ0ZXh0dXJlcyI6eyJTS0lOIjp7InVybCI6Imh0dHA6Ly90ZXh0dXJlcy5taW5lY3JhZnQubmV0L3RleHR1cmUvYjRkMWVkZGVhYzgzMGQ5ZGVhMTJiODg4OTk3YjI4OWZhODRiNjljOTAxZjJjNTc0NGFmOTc1ZmM0OTRlYmUzIn19fQ=="}]}}} 1

    @EventHandler
    public void onServerLoad(ServerLoadEvent e){
        if(boxes.isEmpty() && e.getType()==LoadType.RELOAD){
            for(World world : Bukkit.getWorlds()){
                if(world.getEnvironment()==Environment.NORMAL){
                    for(Chunk chunk : world.getLoadedChunks()){
                        reAddBox(chunk);
                    }
                }
            }
        }
    }
    

    public void spawnMonsterBox(Block block){
        block.setType(Material.SPAWNER);
        CreatureSpawner spawner = (CreatureSpawner) block.getState();
        spawner.setRequiredPlayerRange(0);
        spawner.setSpawnedType(EntityType.MARKER);
        spawner.getPersistentDataContainer().set(SConstants.MONSTERBOX_KEY, PersistentDataType.STRING, "");
        spawner.update();
        boxes.add(spawner.getLocation());
    }

    public void reAddBox(Chunk chunk){
        for(BlockState state : chunk.getTileEntities()){
            if(state instanceof CreatureSpawner){
                CreatureSpawner spawner = (CreatureSpawner) state;
                if(spawner.getPersistentDataContainer().has(SConstants.MONSTERBOX_KEY, PersistentDataType.STRING) && !boxes.contains(spawner.getLocation())){   
                    boxes.add(spawner.getLocation());
                }
            }
        }
    }



    private class BoxRunnable extends BukkitRunnable{

        @Override
        public void run() {
            boxes.removeIf(b -> {
                if(b.getChunk().isLoaded() && b.getBlock().getType() == Material.SPAWNER){
                    return false;
                }
                return true;
            });
            for(Location loc : boxes){
                Block block = loc.getBlock();
                if(block.getType()==Material.SPAWNER){
                    CreatureSpawner spawner = (CreatureSpawner) block.getState();
                    World world = loc.getWorld();
                    if(spawner.getPersistentDataContainer().has(SConstants.MONSTERBOX_KEY, PersistentDataType.STRING)){
                        Location particleLoc = loc.clone().add(0.5, 0.5, 0.5);
                        world.spawnParticle(Particle.SOUL_FIRE_FLAME, particleLoc, 25, 0.4, 0.4, 0.4,0);
                        List<Player> players = world.getNearbyPlayers(loc, 5).stream().filter(pl -> pl.getGameMode()==GameMode.SURVIVAL).collect(Collectors.toList());
                        if(!players.isEmpty()){
                            block.getWorld().playSound(loc, "block.monsterbox.init",1, 1);
                            spawner.getPersistentDataContainer().remove(SConstants.MONSTERBOX_KEY);
                            spawner.update();
                            new BukkitRunnable(){
                                @Override
                                public void run() {
                                    for(Player player : players){

                                        Advancements.awardAdvancement("monsterbox",player);
                                    }
                                    world.spawnParticle(Particle.BLOCK_CRACK, particleLoc, 50, 0.3, 0.3, 0.3,0,Material.SPAWNER.createBlockData());
                                    world.playSound(loc, Sound.BLOCK_GLASS_BREAK, 1, 0.3F);
                                    block.setType(Material.AIR);
                                    for(int i = 0 ; i< ThreadLocalRandom.current().nextInt(10, 20);i++){
                                        LivingEntity l = null;
                                        float r = plugin.RANDOM.nextFloat();
                                        if(r < 0.1){
                                            l = world.spawn(particleLoc, Witch.class);
                                        }
                                        else if(r< 0.3){
                                            l = world.spawn(particleLoc, CaveSpider.class);
                                        }
                                        else if(r < 0.4){
                                            l = world.spawn(particleLoc, Spider.class);
                                        }
                                        else{
                                            l = world.spawn(particleLoc, Zombie.class);
                                        }
                                        double motionMultiplier = 0.4;
                                        double mx = (plugin.RANDOM.nextFloat() - 0.5) * motionMultiplier;
                                        double my = (plugin.RANDOM.nextFloat() - 0.5) * motionMultiplier;
                                        double mz = (plugin.RANDOM.nextFloat() - 0.5) * motionMultiplier;
                                        l.setVelocity(l.getVelocity().add(new Vector(mx,my,mz)));
                                        

                                    }
                                }
                            }.runTaskLater(plugin, 37);
                        }
                    }
                }
            }
        }

        
    }
}

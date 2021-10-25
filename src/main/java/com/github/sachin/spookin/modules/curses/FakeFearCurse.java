package com.github.sachin.spookin.modules.curses;

import java.lang.reflect.InvocationTargetException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;

import com.comphenix.protocol.PacketType;
import com.comphenix.protocol.ProtocolLibrary;
import com.comphenix.protocol.events.PacketContainer;
import com.comphenix.protocol.wrappers.WrappedDataWatcher;
import com.comphenix.protocol.wrappers.WrappedWatchableObject;
import com.comphenix.protocol.wrappers.WrappedDataWatcher.WrappedDataWatcherObject;
import com.github.sachin.spookin.Spookin;

import org.bukkit.Bukkit;
import org.bukkit.Location;
import org.bukkit.Material;
import org.bukkit.NamespacedKey;
import org.bukkit.block.BlockFace;
import org.bukkit.entity.Creeper;
import org.bukkit.entity.Drowned;
import org.bukkit.entity.Enderman;
import org.bukkit.entity.Entity;
import org.bukkit.entity.Husk;
import org.bukkit.entity.Monster;
import org.bukkit.entity.Player;
import org.bukkit.entity.Skeleton;
import org.bukkit.entity.Spider;
import org.bukkit.entity.Zombie;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.scheduler.BukkitRunnable;


public class FakeFearCurse extends BaseCurse{

    private final List<Class<? extends Monster>> fakeboys = Arrays.asList(Zombie.class,Skeleton.class,Creeper.class,Spider.class,Husk.class,Enderman.class);
    private final Map<UUID,List<Integer>> fakeEntities = new HashMap<>();

    public FakeFearCurse(CurseModule instance) {
        super("&eFake Fear", "fake_fear", Arrays.asList("&7Will make you see mobs that aren't real"), Spookin.getKey("fakefear-curse-key"), Arrays.asList(Material.BONE,Material.BLAZE_POWDER), instance);

        new BukkitRunnable(){
            @Override
            public void run() {
                for(Player player : Bukkit.getOnlinePlayers()){
                    if(player.getPersistentDataContainer().has(curseKey, PersistentDataType.STRING) && RANDOM.nextInt(50) > 5){
                        if(fakeEntities.get(player.getUniqueId()) == null){
                            fakeEntities.put(player.getUniqueId(), new ArrayList<>());
                        }
                        Collection<? extends Monster> entities =  player.getWorld().getEntitiesByClass(fakeboys.get(RANDOM.nextInt(fakeboys.size())));
                        if(!entities.isEmpty()){
                            Entity en = entities.iterator().next();
                            Location loc;
                            if(RANDOM.nextInt(2)==1){
                                loc = player.getLocation().clone().add(RANDOM.nextInt(20*2), RANDOM.nextInt(5), RANDOM.nextInt(20*2));
                            }
                            else{
                                loc = player.getLocation().clone().subtract(RANDOM.nextInt(20*2), RANDOM.nextInt(5), RANDOM.nextInt(20*2));
                            }
                            if(loc.getBlock().getType().isAir() && loc.getBlock().getRelative(BlockFace.DOWN).getType().isSolid()){
                                PacketContainer packetContainer = ProtocolLibrary.getProtocolManager().createPacketConstructor(PacketType.Play.Server.SPAWN_ENTITY_LIVING, en).createPacket(en);
                                packetContainer.getDoubles().write(0, loc.getX());
                                packetContainer.getDoubles().write(1, loc.getY());
                                packetContainer.getDoubles().write(2, loc.getZ());
                                packetContainer.getUUIDs().write(0, UUID.randomUUID());
                                int id = instance.getPlugin().RANDOM.nextInt(10000);
                                packetContainer.getIntegers().write(0, id);
                                fakeEntities.get(player.getUniqueId()).add(id);
                                try {
                                    ProtocolLibrary.getProtocolManager().sendServerPacket(player, packetContainer);
                                } catch (InvocationTargetException e) {
                                    e.printStackTrace();
                                }
                            }
                        }
                    }
                }
            }
        }.runTaskTimer(instance.getPlugin(), 0, 100);
    }




    @Override
    public void onRemove(Player player) {

        if(fakeEntities.get(player.getUniqueId()) != null && !fakeEntities.get(player.getUniqueId()).isEmpty()){
            PacketContainer packet = new PacketContainer(PacketType.Play.Server.ENTITY_DESTROY);
            packet.getIntLists().write(0, fakeEntities.get(player.getUniqueId()));
            try {
                ProtocolLibrary.getProtocolManager().sendServerPacket(player, packet);
            } catch (InvocationTargetException e) {
                e.printStackTrace();
            }
            fakeEntities.remove(player.getUniqueId());
        }
    }
}

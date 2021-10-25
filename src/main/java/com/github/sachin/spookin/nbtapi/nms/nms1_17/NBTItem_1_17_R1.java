package com.github.sachin.spookin.nbtapi.nms.nms1_17;

import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.List;
import java.util.function.Predicate;

import com.github.sachin.spookin.nbtapi.nms.NMSHelper;
import com.github.sachin.spookin.utils.SConstants;
import com.google.common.base.Predicates;

import org.bukkit.Location;
import org.bukkit.NamespacedKey;
import org.bukkit.craftbukkit.v1_17_R1.CraftWorld;
import org.bukkit.craftbukkit.v1_17_R1.entity.CraftEntity;
import org.bukkit.craftbukkit.v1_17_R1.inventory.CraftItemStack;
import org.bukkit.entity.Animals;
import org.bukkit.entity.Entity;
import org.bukkit.inventory.ItemStack;
import org.bukkit.persistence.PersistentDataType;

import net.minecraft.core.BlockPosition;
import net.minecraft.nbt.NBTTagCompound;
import net.minecraft.server.level.EntityPlayer;
import net.minecraft.world.entity.EntityCreature;
import net.minecraft.world.entity.EntityLiving;
import net.minecraft.world.entity.EntityTypes;
import net.minecraft.world.entity.ai.goal.PathfinderGoalAvoidTarget;
import net.minecraft.world.entity.ai.navigation.NavigationAbstract;
import net.minecraft.world.entity.ai.util.DefaultRandomPos;
import net.minecraft.world.entity.animal.EntityAnimal;
import net.minecraft.world.entity.monster.EntitySlime;
import net.minecraft.world.item.crafting.RecipeItemStack;
import net.minecraft.world.level.pathfinder.PathEntity;
import net.minecraft.world.phys.Vec3D;

public class NBTItem_1_17_R1 extends NMSHelper{

    private net.minecraft.world.item.ItemStack nmsItem;
    private NBTTagCompound compound;
    private static Method createPath;


    static{
        for(Method m : NavigationAbstract.class.getDeclaredMethods()){
            if(m.getName().equals("createPath")){
                List<Class<?>> params = Arrays.asList(m.getParameterTypes());
                if(params.size()==2 && params.get(0) == BlockPosition.class && params.get(1) == int.class){
                    m.setAccessible(true);
                    createPath = m;
                    break;
                }
            }
        }
    }

    public NBTItem_1_17_R1(ItemStack item){
        if(item == null) return;
        ItemStack bukkitItem = item.clone();
        this.nmsItem = CraftItemStack.asNMSCopy(bukkitItem);
        this.compound = (nmsItem.hasTag()) ? nmsItem.getTag() : new NBTTagCompound();

    }



    @Override
    public NMSHelper newItem(ItemStack item) {
        NMSHelper nbti = new NBTItem_1_17_R1(item);
        return nbti;
    }
    
    @Override
    public void setString(String key,String value){
        compound.setString(key, value);
    }

    @Override
    public ItemStack getItem() {
        nmsItem.setTag(compound);
        return CraftItemStack.asBukkitCopy(nmsItem);
    }

    @Override
    public boolean hasKey(String key) {
        return compound.hasKey(key);
    }

    @Override
    public String getString(String key) {
        return compound.getString(key);
    }

    @Override
    public void removeKey(String key) {
        compound.remove(key);
    }

    @Override
    public void setBoolean(String key, boolean value) {
        compound.setBoolean(key, value);
    }

    @Override
    public boolean getBoolean(String key) {
        return compound.getBoolean(key);
    }

    @Override
    public void setInt(String key, int value) {
        compound.setInt(key, value);
    }

    @Override
    public void setLong(String key, long value) {
        compound.setLong(key, value);
    }

    @Override
    public void setDouble(String key, double value) {
        compound.setDouble(key, value);
        
    }

    @Override
    public int getInt(String key) {
        return compound.getInt(key);
    }

    @Override
    public long getLong(String key) {
        return compound.getLong(key);
    }

    @Override
    public double getDouble(String key) {
        return compound.getDouble(key);
    }
    
    public static RecipeItemStack itemArrayToRecipe(ItemStack[] items, boolean exact) {
        RecipeItemStack.StackProvider[] stacks = new RecipeItemStack.StackProvider[items.length];
        for (int i = 0; i < items.length; i++) {
            stacks[i] = new RecipeItemStack.StackProvider(CraftItemStack.asNMSCopy(items[i]));
        }
        RecipeItemStack itemRecipe = new RecipeItemStack(Arrays.stream(stacks));
        itemRecipe.exact = exact;
        return itemRecipe;
    }


    @Override
    public void addGoal(Animals en,NamespacedKey cursedkey) {
        EntityAnimal animal = (EntityAnimal) ((CraftEntity)en).getHandle();
        PathfinderGoalAvoidTarget<EntityPlayer> goal = new PathfinderGoalAvoidTarget<EntityPlayer>(animal, EntityPlayer.class, 25, 2, 2, (pl) -> pl.getBukkitEntity().getPersistentDataContainer().has(cursedkey, PersistentDataType.STRING));
        animal.bP.a(1, goal);
    }

    @Override
    public void addFleeGoal(Entity en) {
        EntityCreature entity = (EntityCreature) ((CraftEntity)en).getHandle();
        // PathfinderGoalAvoidTarget<EntitySlime> avoidGoal = new PathfinderGoalAvoidTarget<EntitySlime>(entity, EntitySlime.class, 25, 2, 2, (s) -> {return s.getBukkitEntity().getPersistentDataContainer().has(SConstants.SCARECROW_KEY, PersistentDataType.STRING);});
        FleeScareCrowGoal<EntitySlime> avoidGoal = new FleeScareCrowGoal<EntitySlime>(entity, EntitySlime.class, 15, 2, 2, Predicates.alwaysTrue());
        entity.bP.a(3, avoidGoal);
    }

    @Override
    public void summonSkeleHead(Location loc) {
        SkeleHead head = new SkeleHead(loc);
        ((CraftWorld)loc.getWorld()).getHandle().addEntity(head);
    }
    

    private class SkeleHead extends EntitySlime{

        public SkeleHead(Location loc) {
            super(EntityTypes.aD, ((CraftWorld)loc.getWorld()).getHandle());
            this.setPosition(loc.getX(), loc.getY(), loc.getZ());
        }

        
    }


    private class FleeScareCrowGoal<T extends EntityLiving> extends PathfinderGoalAvoidTarget<T>{

        public FleeScareCrowGoal(EntityCreature var0, Class<T> var1, float var2, double var3, double var5,
                Predicate<EntityLiving> var7) {
            super(var0, var1, var2, var3, var5, var7);
        }

        @Override
        public boolean a() {
            List<T> list = this.a.t.a(this.f,this.a.getBoundingBox().grow(this.c, 3, this.c),(sl) -> sl.getBukkitEntity().getPersistentDataContainer().has(SConstants.SCARECROW_KEY, PersistentDataType.STRING));
            
            if (list.isEmpty()){
                return false;
            }
            this.b = list.get(0);
            Vec3D var0 = DefaultRandomPos.a(this.a, 16, 7, this.b.getPositionVector());
            if (var0 == null){
                return false; 
            }
            if(createPath != null){
                try {
                    this.d = (PathEntity) createPath.invoke(this.e, new BlockPosition(var0.b,var0.c,var0.d),0);
                } catch (IllegalAccessException | IllegalArgumentException | InvocationTargetException e) {
                    e.printStackTrace();
                }
            }
            return this.d != null;    
        }

    }
}

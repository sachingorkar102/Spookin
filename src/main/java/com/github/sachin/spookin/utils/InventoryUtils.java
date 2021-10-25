package com.github.sachin.spookin.utils;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;


import org.bukkit.inventory.ItemStack;
import org.bukkit.util.io.BukkitObjectInputStream;
import org.bukkit.util.io.BukkitObjectOutputStream;
import org.yaml.snakeyaml.external.biz.base64Coder.Base64Coder;

public class InventoryUtils {

    // private List<ItemStack> dummyList = new ArrayList<>();

    public static String itemStackListToBase64(List<ItemStack> items){
        try {
            ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
            BukkitObjectOutputStream dataOutput = new BukkitObjectOutputStream(outputStream);
            
            dataOutput.writeInt(items.size());
            
            // for (int i = 0; i < items.length; i++) {
            //     dataOutput.writeObject(items[i]);
            // }
            for (ItemStack itemStack : items) {
                dataOutput.writeObject(itemStack);
            }
            dataOutput.close();
            return Base64Coder.encodeLines(outputStream.toByteArray());
        } catch (Exception e) {
            e.printStackTrace();
        }
        return null;
    }

    public static ItemStack[] base64ToItemStackArray(String string){
        List<ItemStack> dummyList = Arrays.asList(new ItemStack[9]);
        try {
            ByteArrayInputStream inputStream = new ByteArrayInputStream(Base64Coder.decodeLines(string));
            BukkitObjectInputStream dataInput = new BukkitObjectInputStream(inputStream);
            ItemStack[] items = new ItemStack[dataInput.readInt()];
            List<ItemStack> initialList = new ArrayList<>();
            for (int i = 0; i < items.length; i++) {
                items[i] = (ItemStack)dataInput.readObject();
                initialList.add(items[i]);
            }
            for (int i=0;i<9;i++){
                
                dummyList.set(i, initialList.get(0));
                initialList.remove(0);

            }
            dataInput.close();
            return dummyList.toArray(new ItemStack[0]);
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
            
        } catch (IOException e) {
            e.printStackTrace();
        }
        return null;
    }

    public static String serializeItem(ItemStack item){
        try {
            ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
            BukkitObjectOutputStream dataOutput = new BukkitObjectOutputStream(outputStream);
            // dataOutput.writeInt(1);
            dataOutput.writeObject(item);
            dataOutput.close();
            return Base64Coder.encodeLines(outputStream.toByteArray());
        } catch (Exception e) {
            System.out.println("Error occured while serializing item");
            e.printStackTrace();
        }
        return null;
    }

    public static ItemStack deserializeItem(String string){
        try {
            ByteArrayInputStream inputStream = new ByteArrayInputStream(Base64Coder.decodeLines(string));
            BukkitObjectInputStream dataInput = new BukkitObjectInputStream(inputStream);
            ItemStack item = (ItemStack)dataInput.readObject();
            if(item != null){
                return item;
            }
        } catch (Exception e) {
            System.out.println("Error occured while deserializing item");
            e.printStackTrace();
        }
        return null;
    }

    
    
}

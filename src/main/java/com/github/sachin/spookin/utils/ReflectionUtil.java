package com.github.sachin.spookin.utils;

import java.lang.reflect.Field;

import com.google.common.collect.HashBasedTable;
import com.google.common.collect.Table;

public class ReflectionUtil {

    private static final Table<Class<?>,String,Field> fieldCache = HashBasedTable.create();
   
    
    public static Field getFieldCached(final Class<?> clazz, final String fieldName) {
        if (fieldCache.contains(clazz, fieldName)) {
            return fieldCache.get(clazz, fieldName);
        }
        try {
            final Field field = clazz.getDeclaredField(fieldName);
            field.setAccessible(true);
            fieldCache.put(clazz, fieldName, field);
            return field;
        } catch (final NoSuchFieldException e) {
            return null;
        }
    }


}

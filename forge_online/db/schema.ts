import {sqliteTable,text,integer,real,primaryKey,index} from 'drizzle-orm/sqlite-core';
export const records=sqliteTable('user_records',{
 userId:text('user_id').notNull(),recordKey:text('record_key').notNull(),value:text('value_json'),clock:text('clock').notNull(),deleted:integer('deleted').notNull().default(0),updatedAt:text('updated_at').notNull()
},table=>[primaryKey({columns:[table.userId,table.recordKey]})]);
export const foods=sqliteTable('foods',{
 id:integer('fdc_id').primaryKey(),name:text('name').notNull(),calories:real('calories').notNull(),protein:real('protein').notNull(),carbs:real('carbs').notNull(),fat:real('fat').notNull(),data:text('data_json').notNull()
},table=>[index('foods_name_idx').on(table.name)]);
export const catalogState=sqliteTable('catalog_state',{id:integer('id').primaryKey(),cursor:integer('cursor').notNull().default(0),complete:integer('complete').notNull().default(0)});
export const recipes=sqliteTable('recipes',{userId:text('user_id').notNull(),id:text('id').notNull(),name:text('name').notNull(),data:text('data_json').notNull(),updatedAt:text('updated_at').notNull()},table=>[primaryKey({columns:[table.userId,table.id]})]);
export const credentials=sqliteTable('user_credentials',{userId:text('user_id').primaryKey(),encryptedKey:text('encrypted_key').notNull(),updatedAt:text('updated_at').notNull()});
export const usage=sqliteTable('ai_usage',{userId:text('user_id').notNull(),day:text('day').notNull(),count:integer('count').notNull().default(0)},table=>[primaryKey({columns:[table.userId,table.day]})]);
export const regionalFoods=sqliteTable('regional_foods',{id:text('id').primaryKey(),name:text('name').notNull(),data:text('data_json').notNull()});
export const packagedFoods=sqliteTable('packaged_foods',{userId:text('user_id').notNull(),id:text('id').notNull(),name:text('name').notNull(),data:text('data_json').notNull(),updatedAt:text('updated_at').notNull()},table=>[primaryKey({columns:[table.userId,table.id]})]);
export const productLookupCache=sqliteTable('product_lookup_cache',{key:text('cache_key').primaryKey(),data:text('data_json').notNull(),expiresAt:integer('expires_at').notNull()});
export const providerCredentials=sqliteTable('provider_credentials',{userId:text('user_id').notNull(),provider:text('provider').notNull(),encryptedKey:text('encrypted_key').notNull()},table=>[primaryKey({columns:[table.userId,table.provider]})]);


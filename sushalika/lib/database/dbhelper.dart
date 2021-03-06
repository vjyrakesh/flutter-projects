/// Helper class to interact with SQLite database.

import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sushalika/model/item.dart';
import 'package:sushalika/model/list.dart';
import 'package:sushalika/model/list_item.dart';
import 'package:flutter/services.dart' show rootBundle;

class DBHelper {
  static Database _db;

  Future<Database> get db async {
    if (_db != null) return _db;
    _db = await initDb();
    return _db;
  }

  /// Initialise the database.
  /// Makes a working copy of the database from the bundle.
  initDb() async {
    io.Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "working_copy.db");
    io.FileSystemEntity fileObj = new io.File(path);
    if (!fileObj.existsSync()) {
//      fileObj.deleteSync();
      ByteData data = await rootBundle.load(join("assets", "shopping.db"));
      List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await new io.File(path).writeAsBytes(bytes);
    }
    var theDb = await openDatabase(path);
    return theDb;
  }

  /// Run this method first time when the database is created.
  void _onCreate(Database db, int version) async {
    await db.execute("create table items(item_id integer primary key autoincrement, item_name varchar(30))");
    await db.execute("insert into items(item_name) values('soap')");
    await db.execute("insert into items(item_name) values('shampoo')");
  }

  /// Get the complete list of items from the database.
  Future<List<Item>> getItems() async {
    var dbClient = await db;
    List<Map> list = await dbClient.rawQuery("select item_name from items order by item_name");
    List<Item> items = new List();
    for (int i = 0; i < list.length; i++) {
      items.add(new Item(list[i]["item_name"]));
    }
    return items;
  }

  /// Get all shopping lists.
  Future<List<ShoppingList>> getShoppingLists() async {
    var dbClient = await db;
    List<Map> list = await dbClient.rawQuery("select list_name,list_created_at from lists order by list_created_at desc");
    List<ShoppingList> shoppingLists = new List();
    for (int i = 0; i < list.length; i++) {
      shoppingLists.add(new ShoppingList(list[i]['list_name'], list[i]['list_created_at']));
    }
    return shoppingLists;
  }

  Future<int> getListId(String listName) async {
    var dbClient = await db;
    List<Map> itemList = await dbClient.rawQuery("select list_id from lists where list_name=\'$listName\'");
    if (itemList != null && itemList.length > 0)
      return itemList[0]['list_id'];
    else
      return 0;
  }

  Future<int> getItemId(String itemName) async {
    var dbClient = await db;
    List<Map> itemList = await dbClient.rawQuery("select item_id from items where item_name=\'$itemName\'");
    int itemId = itemList[0]['item_id'];
    return itemId;
  }

  /// Get all items in a shopping list.
  Future<List<ShoppingListItem>> getShoppingListItems(String list_name) async {
    var dbClient = await db;
    int listId = await getListId(list_name);
    List<Map> list = await dbClient.rawQuery("select item_name,quantity from items i inner join list_items li on i.item_id=li.item_id where list_id=$listId");
    List<ShoppingListItem> shoppingListItems = new List();
    for(int i = 0; i < list.length; i++) {
      shoppingListItems.add(new ShoppingListItem(list[i]['item_name'], list[i]['quantity']));
    }
    shoppingListItems.sort((a,b){
      return a.itemName.compareTo(b.itemName);
    });
    if (shoppingListItems.length > 0)
      return shoppingListItems;
    else {
      return null;
    }
  }

  Future<int> addShoppingList(String listName) async {
    var dbClient = await db;
    String now = new DateTime.now().toString();
    await dbClient.transaction((txn) async {
      int res = await txn.rawInsert("insert into lists(list_name,list_created_at) values(\'$listName\',\'$now\')");
      return res;
    });
    List<Map> resList = await dbClient.rawQuery("select list_id from lists where list_name=\'$listName\'");
    if (resList.length > 0) {
      return resList[0]['list_id'];
    }
    return 0;
  }

  Future<int> addShoppingListItems(int listId, Map<String,String> listItems) async {
    var dbClient = await db;
    int res = 0;

    for (var entry in listItems.entries) {
      String itemName = entry.key;
      String quantity = entry.value;
      int itemId = await getItemId(itemName);
      await dbClient.transaction((txn) async {
        res = await txn.rawInsert(
            "insert into list_items values($listId,$itemId,\'$quantity\')");
      });
    }
    return res;
  }

  Future<int> addItemsToShoppingList(String listName, Map<String,String> listItems) async {
    int res = 0;
    int listId = await getListId(listName);
    if (listId == 0) {
      listId = await addShoppingList(listName);
    }
    if (listItems.length > 0)
      res = await addShoppingListItems(listId, listItems);
    else
      res = listId;
    return res;
  }

  Future<int> removeItemsFromShoppingList(String listName) async {
    int listId = await getListId(listName);
    int res = 0;
    var dbClient = await db;
    await dbClient.transaction((txn) async{
      res = await txn.rawDelete("delete from list_items where list_id=$listId");
    });
    return res;
  }

  void removeShoppingList(String listName) async {
    int listId = await getListId(listName);
    var dbClient = await db;
    await dbClient.rawDelete("delete from lists where list_id=$listId");
  }

  Future<int> removeOneItemFromList(String listName, String itemName) async {
    int listId = await getListId(listName);
    int itemId = await getItemId(itemName);
    var dbClient = await db;
    await dbClient.transaction((txn) async {
      return await txn.rawDelete("delete from list_items where list_id=$listId and item_id=$itemId");
    });
    return 0;
  }

  Future<int> addNewItem(String itemName) async {
    var dbClient = await db;
    int res = 0;
    await dbClient.transaction((txn) async {
      res = await txn.rawInsert("insert into items(item_name) values(\'$itemName\')");
    });
    return res;
  }
}
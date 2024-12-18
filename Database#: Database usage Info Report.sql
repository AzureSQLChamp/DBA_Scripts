--Single database:

Use YourDatabaseHere;
     Go

   With dbSizes (db_size, log_size) 
     As (
 Select sum(convert(bigint, Case When status & 64 = 0 Then size Else 0 End))
      , sum(convert(bigint, Case When status & 64 != 0 Then size Else 0 End))
   From dbo.sysfiles
        )
      , pagesUsed (reserved_pages, used_pages, total_pages) 
     As (
 Select sum(a.total_pages)
      , sum(a.used_pages)
      , sum(Case When it.internal_type In (202, 204) Then 0
                 When a.type != 1 Then a.used_pages
                 When p.index_id < 2 Then a.data_pages
                 Else 0
             End)
   From sys.partitions                   p
  Inner Join sys.allocation_units        a On p.partition_id = a.container_id
   Left Join sys.internal_tables        it On p.object_id = it.object_id
        )
 Select database_size_gb = cast(s.database_size_mb / 1024 As decimal(19,4))
      , s.database_size_mb
      , s.reserved_mb
      , s.data_mb
      , s.log_size_mb
      , s.index_mb
      , s.unused_mb
      , s.unallocated_mb
      , data_reserved_mb = s.reserved_mb + s.unallocated_mb
      , unallocated = cast(s.unallocated_mb * 100.0 / (s.reserved_mb + s.unallocated_mb) As decimal(19,4))
      , data_used = cast(s.data_mb * 100 / (s.reserved_mb + s.unallocated_mb) As decimal(19,4))
      , index_used = cast(s.index_mb * 100 / (s.reserved_mb + s.unallocated_mb) As decimal(19,4))
      , unused = cast(s.unused_mb * 100 / (s.reserved_mb + s.unallocated_mb) As decimal(19,4))
   From pagesUsed               pu
  Cross Apply dbSizes           ds
  Cross Apply (Values (convert(decimal(19,4), (ds.db_size + ds.log_size) * 8192 / 1048576.0)
                     , cast(pu.reserved_pages * 8192 / 1048576.0 As decimal(19,4))
                     , cast(pu.total_pages * 8192 / 1048576.0 As decimal(19,4))
                     , cast(ds.log_size * 8192 / 1048576.0 As decimal(19,4))
                     , cast((pu.used_pages - pu.total_pages) * 8192 / 1048576.0 As decimal(19,4))
                     , cast((pu.reserved_pages - pu.used_pages) * 8192 / 1048576.0 As decimal(19,4))
                     , Case When ds.db_size >= pu.reserved_pages 
                            Then convert(decimal(19,4), (ds.db_size - pu.reserved_pages) * 8192 / 1048576.0)
                            Else 0
                        End)
              ) As s(database_size_mb, reserved_mb, data_mb, log_size_mb, index_mb, unused_mb, unallocated_mb);

--Multiple database's

Use Works;
     Go

Declare @database sysname
      , @sqlCommand nvarchar(max) = '';

Declare dbList Cursor Local fast_forward
    For
 Select db.name 
   From sys.databases                    db;

 --==== Open and fetch
   Open dbList;
  Fetch Next From dbList Into @database;

  While @@fetch_status = 0
  Begin

    Set @sqlCommand = '
    Use ' + quotename(@database) + ';
  
   With dbSizes (db_size, log_size) 
     As (
 Select sum(convert(bigint, Case When status & 64 = 0 Then size Else 0 End))
      , sum(convert(bigint, Case When status & 64 != 0 Then size Else 0 End))
   From dbo.sysfiles
        )
      , pagesUsed (reserved_pages, used_pages, total_pages) 
     As (
 Select sum(a.total_pages)
      , sum(a.used_pages)
      , sum(Case When it.internal_type In (202, 204) Then 0
                 When a.type != 1 Then a.used_pages
                 When p.index_id < 2 Then a.data_pages
                 Else 0
             End)
   From sys.partitions                   p
  Inner Join sys.allocation_units        a On p.partition_id = a.container_id
   Left Join sys.internal_tables        it On p.object_id = it.object_id
        )
 Select database_id = db_id()
      , database_name = db_name()
      , database_size_gb = cast(s.database_size_mb / 1024 As decimal(19,4))
      , s.database_size_mb
      , s.reserved_mb
      , s.data_mb
      , s.log_size_mb
      , s.index_mb
      , s.unused_mb
      , s.unallocated_mb
      , data_reserved_mb = s.reserved_mb + s.unallocated_mb
      , unallocated = cast(s.unallocated_mb * 100.0 / (s.reserved_mb + s.unallocated_mb) As decimal(19,4))
      , data_used = cast(s.data_mb * 100 / (s.reserved_mb + s.unallocated_mb) As decimal(19,4))
      , index_used = cast(s.index_mb * 100 / (s.reserved_mb + s.unallocated_mb) As decimal(19,4))
      , unused = cast(s.unused_mb * 100 / (s.reserved_mb + s.unallocated_mb) As decimal(19,4))
   From pagesUsed               pu
  Cross Apply dbSizes           ds
  Cross Apply (Values (convert(decimal(19,4), (ds.db_size + ds.log_size) * 8192 / 1048576.0)
                     , cast(pu.reserved_pages * 8192 / 1048576.0 As decimal(19,4))
                     , cast(pu.total_pages * 8192 / 1048576.0 As decimal(19,4))
                     , cast(ds.log_size * 8192 / 1048576.0 As decimal(19,4))
                     , cast((pu.used_pages - pu.total_pages) * 8192 / 1048576.0 As decimal(19,4))
                     , cast((pu.reserved_pages - pu.used_pages) * 8192 / 1048576.0 As decimal(19,4))
                     , Case When ds.db_size >= pu.reserved_pages 
                            Then convert(decimal(19,4), (ds.db_size - pu.reserved_pages) * 8192 / 1048576.0)
                            Else 0
                        End)
              ) As s(database_size_mb, reserved_mb, data_mb, log_size_mb, index_mb, unused_mb, unallocated_mb);
'

 --==== Print/Execute SQL Command
  Print @sqlCommand;
 Execute sp_executeSql @sqlCommand;

  Fetch Next From dbList Into @database;

    End 

  Close dbList;
Deallocate dbList;

!>Contains methods related to parallelism
MODULE module_MPI
  USE module_structure
CONTAINS



!>Sends the partitionning
!!@details This method sends to each slave process the
!!number of points, the dimension and all the points 
!!of the dedicated domain. Then, it creates
!!@note It has to be called by the master process
!!@see receive_partitioning(), partition_with_interface(), partition_with_overlapping()
!! @param[in] assignments the assignement of each point in a partition
!! @param[in] nb_proc the number of processors used
!! @param[in] points_by_domain the number of points in each partition
!! @param[in,out] data the entire data for computing
!! @param[out] partitioned_data the partitioned data for computing
  SUBROUTINE send_partitioning(nb_proc, data, points_by_domain, assignments, partitioned_data)
    IMPLICIT NONE    
    ! MPI library
    INCLUDE 'mpif.h'
    !###########################################
    ! DECLARATIONS
    !###########################################      
    !#### Parameters ####
    !====  IN  ====
    INTEGER, DIMENSION(:,:), POINTER :: assignments
    INTEGER, DIMENSION(:), POINTER :: points_by_domain
    INTEGER :: nb_proc

    !=== IN/OUT ===
    TYPE(type_data) :: data

    !====  OUT ====
    TYPE(type_data) :: partitioned_data
    
    !#### Variables  ####
    DOUBLE PRECISION, DIMENSION(:,:), POINTER :: coords
    INTEGER :: i
    INTEGER :: j
    INTEGER :: ierr
    INTEGER :: m
    INTEGER :: n
    INTEGER :: id_mpi
    
    !###########################################      
    ! INSTRUCTIONS
    !###########################################  
    DO i=1,nb_proc-1
       m=points_by_domain(i)
       n=data%dim
       id_mpi=i
       CALL MPI_SEND(m,1,MPI_INTEGER,i,id_mpi,MPI_COMM_WORLD,ierr)
       CALL MPI_SEND(n,1,MPI_INTEGER,i,id_mpi,MPI_COMM_WORLD,ierr)   
       IF (m>0) THEN
          ! Creation of coordinates arrays
          ALLOCATE(coords(m,n))
          coords=0.0
          DO j=1,m
             coords(j,1:n)=data%points(assignments(i,j))%coords(1:n)
          ENDDO
          ! Sending arrays
          id_mpi=i*10
          CALL MPI_SEND(coords,m*n,MPI_DOUBLE_PRECISION,i,id_mpi,MPI_COMM_WORLD,ierr)
          DEALLOCATE(coords)
       ENDIF
    ENDDO
    ! Creation of TYPE partitioned_data of interface
    m=points_by_domain(0)
    n=data%dim
    partitioned_data%nb_points=m
    partitioned_data%dim=n
    partitioned_data%nb_clusters=0
    IF (m>0) THEN
       ALLOCATE(partitioned_data%points(m))
       DO i=1,m
          ALLOCATE(partitioned_data%points(i)%coords(n))
          partitioned_data%points(i)%coords(:)=data%points(assignments(0,i))%coords(:)
          partitioned_data%points(i)%cluster=0
       ENDDO
    ENDIF
    ! Sending flags picture, threshold, geometric...
    n=data%coords
    partitioned_data%coords=n
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    n=data%is_image
    partitioned_data%is_image=n
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    n=data%is_geom
    partitioned_data%is_geom=n
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    n=data%is_threshold
    partitioned_data%is_threshold=n
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    n=data%is_overlapping
    partitioned_data%is_overlapping=n
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    n=data%is_interfacing
    partitioned_data%is_interfacing=n
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    n=data%dim
    partitioned_data%dim=n
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    RETURN
  END SUBROUTINE send_partitioning


!>Receives the partitionning
!!@details This method receives from the master process 
!!the number of points, the dimension and all the points 
!!of the dedicated domain.
!!@note It has to be called by a slave process
!!@see send_partitioning(), partition_with_interface(), partition_with_overlapping()
!! @param[in] proc_id the processus identifier
!! @param[out] partitioned_data the partitioned data for computing
  SUBROUTINE receive_partitioning(proc_id, partitioned_data)
    IMPLICIT NONE
    ! MPI library
    INCLUDE 'mpif.h'
    !###########################################
    ! DECLARATIONS
    !###########################################      
    !#### Parameters ####
    !====  IN  ====
    INTEGER :: proc_id

    !====  OUT ====
    TYPE(type_data) :: partitioned_data
    
    !#### Variables  ####
    DOUBLE PRECISION, DIMENSION(:,:), POINTER :: coords
    INTEGER status(MPI_STATUS_SIZE)
    INTEGER :: i
    INTEGER :: ierr
    INTEGER :: m
    INTEGER :: n
    INTEGER :: id_mpi
    
    !###########################################      
    ! INSTRUCTIONS
    !###########################################   
    ! Receiving dimensions
    id_mpi=proc_id
    CALL MPI_RECV(m,1,MPI_INTEGER,0,id_mpi,MPI_COMM_WORLD,status,ierr)
    CALL MPI_RECV(n,1,MPI_INTEGER,0,id_mpi,MPI_COMM_WORLD,status,ierr)
    partitioned_data%nb_points=m
    partitioned_data%dim=n
    partitioned_data%nb_clusters=0
    IF (m>0) THEN
       ALLOCATE(coords(m,n))
       coords=0.0
       ! Receiving arrays
       id_mpi=proc_id*10
       CALL MPI_RECV(coords,m*n,MPI_DOUBLE_PRECISION,0,id_mpi,&
            MPI_COMM_WORLD,status,ierr)
       ! Creation of TYPE partitioned_data of subdomain
       ALLOCATE(partitioned_data%points(m))
       DO i=1,m
          ALLOCATE(partitioned_data%points(i)%coords(n))
          partitioned_data%points(i)%coords=coords(i,:)
          partitioned_data%points(i)%cluster=0
       ENDDO
       DEALLOCATE(coords)
    ENDIF
    ! Sending flags picture, threshold, geometric...
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    partitioned_data%coords=n
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    partitioned_data%is_image=n
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    partitioned_data%is_geom=n
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    partitioned_data%is_threshold=n
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    partitioned_data%is_overlapping=n
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    partitioned_data%is_interfacing=n
    CALL MPI_BCAST(n,1,MPI_INTEGER,0,MPI_COMM_WORLD,ierr)
    partitioned_data%dim=n
    RETURN
  END SUBROUTINE receive_partitioning



!>Receives the number of clusters
!!@details This method receives from the slave processes
!!the number of clusters in each domain and the number of
!!elements in each cluster.
!!@note It has to be called by the master process.
!!@see send_number_clusters()
!! @param[in] partitioned_data the partitioned data for computing
!! @param[in] nb_proc the number of processors used
!! @param[in] points_by_domain the number of points in each partition
!! @param[out] array_clust the number of clusters and elements per cluster computed by each processor
!! @param[out] nb_clusters the number of clusters
!! @param[out] nb_clusters the number of clusters
!! @param[out] nb_clusters the number of clusters
  SUBROUTINE receive_number_clusters(nb_proc, nb_clusters, points_by_domain, partitioned_data, array_clust)
    IMPLICIT NONE
    ! MPI library
    INCLUDE 'mpif.h'
    !###########################################
    ! DECLARATIONS
    !###########################################      
    !#### Parameters ####
    !====  IN  ==== 
    TYPE(type_data) ::partitioned_data
    INTEGER, DIMENSION(:), POINTER :: points_by_domain
    INTEGER :: nb_proc

    !====  OUT ====
    TYPE(type_clusters), DIMENSION(:), POINTER :: array_clust
    INTEGER :: nb_clusters
    
    !#### Variables  ####    
    INTEGER status(MPI_STATUS_SIZE)
    INTEGER :: i
    INTEGER :: ierr
    INTEGER :: nb
    INTEGER :: id_mpi
    
    !###########################################      
    ! INSTRUCTIONS
    !########################################### 
    IF (partitioned_data%nb_points>0) THEN
       nb_clusters=partitioned_data%nb_clusters
    ELSE
       nb_clusters=0
    ENDIF
    ! Numebr of clusters
    ALLOCATE(array_clust(nb_proc))
    array_clust(:)%nb=0
    DO i=1,nb_proc-1
       IF (points_by_domain(i)>0) THEN
          id_mpi=i*11
          CALL MPI_RECV(nb,1,MPI_INTEGER,i,id_mpi,MPI_COMM_WORLD,status,ierr)
          nb_clusters=nb_clusters+nb
          array_clust(i)%nb=nb
       ENDIF
    ENDDO
    ! Number of points by cluster
    DO i=1,nb_proc-1
       IF (points_by_domain(i)>0) THEN
          id_mpi=i*11+1
          ALLOCATE(array_clust(i)%nb_elements(array_clust(i)%nb))
          CALL MPI_RECV(array_clust(i)%nb_elements,array_clust(i)%nb,MPI_INTEGER,i,id_mpi,MPI_COMM_WORLD,status,ierr)
       ENDIF
    ENDDO
    RETURN
  END SUBROUTINE receive_number_clusters


!>Sends the number of clusters
!!@details This method sends to the master process the
!!number of clusters and the number of elements in each 
!!cluster.
!!@note It has to be called by a slave process.
!!@see receive_number_clusters()
!! @param[in] partitioned_data the partitioned data for computing
!! @param[in] proc_id the processus identifier
  SUBROUTINE send_number_clusters(proc_id, partitioned_data)
    IMPLICIT NONE
    ! MPI library
    INCLUDE 'mpif.h'
    !###########################################
    ! DECLARATIONS
    !###########################################      
    !#### Parameters ####
    !====  IN  ====
    TYPE(type_data) ::partitioned_data
    INTEGER :: proc_id

    !#### Variables  ####
    INTEGER, DIMENSION(:), POINTER :: list
    INTEGER :: id_mpi
    INTEGER :: i
    INTEGER :: ierr
    
    !###########################################      
    ! INSTRUCTIONS
    !###########################################
    IF (partitioned_data%nb_points>0) THEN
       ! Number of clusters
       id_mpi=proc_id*11
       CALL MPI_SEND(partitioned_data%nb_clusters,1,MPI_INTEGER,0,id_mpi,MPI_COMM_WORLD,ierr)
       ! Number of points by cluster
       ALLOCATE(list(partitioned_data%nb_clusters))
       list(:) = 0
       DO i=1,partitioned_data%nb_points
          list(partitioned_data%points(i)%cluster)=list(partitioned_data%points(i)%cluster)+1
       ENDDO
       id_mpi=id_mpi+1
       CALL MPI_SEND(list,partitioned_data%nb_clusters,MPI_INTEGER,0,id_mpi,MPI_COMM_WORLD,ierr)
    ENDIF
    RETURN
  END SUBROUTINE send_number_clusters



!>Sends the clusters
!!@details This method sends the computed clusters to the
!!master process.
!!@note It has to be called by a slave process.
!!@see receive_clusters()
!! @param[in] partitioned_data the partitioned data for computing
!! @param[in] proc_id the processus identifier
  SUBROUTINE send_clusters(proc_id, partitioned_data)
    IMPLICIT NONE
    ! MPI library
    INCLUDE 'mpif.h'
    !###########################################
    ! DECLARATIONS
    !###########################################      
    !#### Parameters ####
    !====  IN  ====
    TYPE(type_data) :: partitioned_data
    INTEGER :: proc_id
    
    !#### Variables  ####  
    INTEGER, DIMENSION(:), POINTER :: list_clusters
    INTEGER :: i
    INTEGER :: ierr
    INTEGER :: id_mpi
    
    !###########################################      
    ! INSTRUCTIONS
    !###########################################    
    IF (partitioned_data%nb_points>0) THEN
       ALLOCATE(list_clusters(partitioned_data%nb_points))
       DO i=1,partitioned_data%nb_points
          list_clusters(i)=partitioned_data%points(i)%cluster
       ENDDO
       id_mpi=proc_id*12
       CALL MPI_SEND(list_clusters,partitioned_data%nb_points,MPI_INTEGER,0,id_mpi,MPI_COMM_WORLD,ierr)
       DEALLOCATE(list_clusters)
    ENDIF
    RETURN
  END SUBROUTINE send_clusters



!>Receives the clusters
!!@details This method receives the computed clusters in 
!!each domain from the slave processes.
!!@note It has to be called by the master process.
!!@see send_clusters()
!! @param[in] array_clust the number of clusters and elements per cluster computed by each processor
!! @param[in] partitioned_data the partitioned data for computing
!! @param[in] assignments the assignement of each point in a partition
!! @param[in] nb_clusters the number of clusters
!! @param[in] nb_clusters the number of clusters
!! @param[in] nb_clusters the number of clusters
!! @param[in] nb_proc the number of processors used
!! @param[in] points_by_domain the number of points in each partition
!! @param[out] cluster_map the cluster indices and the number of points in each cluster
!! @param[out] points_by_cluster the number of points in each cluster
  SUBROUTINE receive_clusters(nb_proc, nb_clusters, points_by_domain, assignments, partitioned_data, cluster_map, &
       array_clust, points_by_cluster)
    IMPLICIT NONE
    ! MPI library
    INCLUDE 'mpif.h'
    !###########################################
    ! DECLARATIONS
    !###########################################      
    !#### Parameters ####
    !====  IN  ====
    TYPE(type_clusters), DIMENSION(:), POINTER :: array_clust
    TYPE(type_data) ::partitioned_data
    INTEGER, DIMENSION(:,:), POINTER :: assignments
    INTEGER, DIMENSION(:), POINTER :: points_by_domain 
    INTEGER :: nb_proc
    INTEGER :: nb_clusters

    !====  OUT ====
    INTEGER, DIMENSION(:,:), POINTER :: cluster_map
    INTEGER, DIMENSION(:), POINTER :: points_by_cluster
    
    !#### Variables  ####
    INTEGER, DIMENSION(:), POINTER :: list_clusters
    INTEGER status(MPI_STATUS_SIZE)
    INTEGER :: i
    INTEGER :: i0
    INTEGER :: ierr
    INTEGER :: j
    INTEGER :: k
    INTEGER :: points_max
    INTEGER :: p
    
    !###########################################      
    ! INSTRUCTIONS
    !###########################################    
    i0=0
    ALLOCATE(points_by_cluster(nb_clusters))
    points_by_cluster(:)=0
    IF (partitioned_data%nb_points>0) THEN
       ! Storage of local clusters in the global array
       DO i=1,partitioned_data%nb_points
          j=partitioned_data%points(i)%cluster
          points_by_cluster(j)=points_by_cluster(j)+1
          cluster_map(j,points_by_cluster(j))=assignments(0,i)
       ENDDO
       i0=i0+partitioned_data%nb_clusters
    ENDIF
    points_max = maxval(points_by_domain)
    ALLOCATE(list_clusters(points_max))
    DO i=1,nb_proc-1
       IF (points_by_domain(i)>0) THEN
          ! Receiving local allocations of subdomain points
          CALL MPI_RECV(list_clusters,points_max,MPI_INTEGER,MPI_ANY_SOURCE,MPI_ANY_TAG,MPI_COMM_WORLD,status,ierr)
#if aff
          PRINT *, 'DEBUG : MPI_RECV ', i, status(1), status(2), status(3), status(4) 
#endif
          p = status(MPI_SOURCE)
          ! Storage of local clusters in the global array
          DO j=1,points_by_domain(p)
             k=list_clusters(j)+i0
             points_by_cluster(k)=points_by_cluster(k)+1
             cluster_map(k,points_by_cluster(k))=assignments(p,j)
          ENDDO
          i0=i0+array_clust(p)%nb
       ENDIF
    ENDDO
    DEALLOCATE(list_clusters)
    RETURN
  END SUBROUTINE receive_clusters


END MODULE module_MPI

# Práctica 1 - Lista de Tareas - PARTE 2

## Desarrollo de una app móvil en Kotlin (Android Studio) para gestionar una lista de tareas

### PARTE 2:

4. **Implementación de Room.**

	Una base de datos de Room en Android es una biblioteca de persistencia que proporciona una capa de abstracción sobre SQLite. Se trata de una persistencia a nivel local.

	4.1. Incluir las dependencias necesarias para utilizar Room. Las insertaremos en build.gradle.kts (Module):

    ```
	dependencies {
		...

		//Room
		implementation("androidx.room:room-runtime:2.5.0")
		annotationProcessor("androidx.room:room-compiler:2.5.0")

		//To use Kotlin annotation processing tool (kapt)
		kapt("androidx.room:room-compiler:2.5.0")
	}
    ```

	4.2. Lo primero es crear la base de datos. Dentro de la carpeta data crearemos un fichero con el nombre `TasksManageDatabase` que contendrá una clase abstracta que extenderá de ***RoomDatabase***:

    ```
	//TaskEntity::class te dará una referencia al objeto KClass que representa la clase TaskEntity. 
	//Esto es útil, por ejemplo, cuando necesitas trabajar con la clase de manera dinámica, 
	//como para obtener información sobre sus miembros, crear instancias de la clase, etc.
	@Database(entities = [TaskEntity::class], version = 1)
	abstract class TasksManageDatabase: RoomDatabase() {
		//DAO
		abstract fun taskDao():TaskDao
	}
    ```
    
	***Necesitamos crear las entidades de la base de datos...*** en nuestro caso será muy simple y solo contendrá una entidad, que básicamente tendrá los mismos campos de mi data class TaskModel... es la información que nosotros queremos que persista en la base de datos.
	
	***No vamos a usar la misma clase TaskModel*** porque este es un modelo de la capa de UI y deberíamos evitar que un modelo de UI, un modelo de data y un modelo de dominio sea el mismo *(evitar el acoplamiento de capas)*.
	
	Aunque para este proyecto tan simple con una única entidad, después usaremos el mismo modelo para la capa de UI y dominio, pero la capa de data si que debe tener su propio modelo distinto a las otras capas *(separación de capas)*.
	
	En la carpeta data creamos la entidad TaskEntity, que será también una data class:

    ```
	//La Entidad es el modelo de datos que vamos a persistir en nuestra base de datos...
	@Entity
	data class TaskEntity (
		@PrimaryKey
		val id: Int,
		val task: String,
		var selected: Boolean = false
	)
    ```
    	
	También vamos a hacer una pequeña modificación en la data class TaskModel para utilizar una función hash en la generación del id y dejarlo también cómo tipo de datos Int:

    ```
	//Nuestro modelo de datos...
	data class TaskModel(
		//El método hashcode() nos crea un código único a través del número de milisegundos al que aplica...
		//El hascode() es lo que utiliza el compilador para comparar objetos, es decir, 
		//lo hace a través del hashcode() que se genera en cada objeto.
		val id: Int = System.currentTimeMillis().hashCode(),
		val task: String,
		var selected: Boolean = false
	)
    ```
    	
	Al final estamos trabajando con una base de datos con la que vamos a interactuar utilizando SQL... necesitamos crearnos un **`DAO`** ***(Data Access Object)***, que es dónde escribiremos nuestras consultas SQL.
	
	Los DAOs en Room se utilizan para definir métodos que interactúan con la base de datos.
	
	En este caso será un Interface, se ubicará también en la carpeta data y le daremos el nombre TaskDao:

    ```
	/**
	 * Define una interfaz que contiene métodos para interactuar con la tabla TaskEntity en la base de datos.
	 */
	@Dao
	interface TaskDao {
		@Query("SELECT * from TaskEntity")
		//Básicamente nos vamos a enganchar a través de Flow, va a retornar un Flow con una lista de TaskEntity, 
		//y las librerías de Flow se encargarán de avisar cuando algún dato de la Entidad se haya agregado, actualizado o eliminado
		fun getTasks(): Flow<List<TaskEntity>>
		
		@Insert
		suspend fun addTask(item:TaskEntity)
	}
    ```
    	
	4.3. Lo siguiente será incluir Room con la inyección de dependencias de Dagger Hilt.
	
	Para este apartado nos vamos a crear una nueva carpeta dentro de data, que se llamará **`di`**, y es dónde incluiremos el módulo de la base de datos, que será una clase de Kotlin con el nombre **`DatabaseModule`**:

    ```
	//Debe ser un Singleton	para que la base de datos sea única en nuestro proyecto.
	//Utilizaremos la notación de Hilt con @Provides.
	@Module
	@InstallIn(SingletonComponent::class)
	class DatabaseModule {
		//Aquí va a recibir la base de datos mediante la inyección de Dagger Hilt...
		//es una caja negra para nosotros, las maravillas de la inyección de dependencias...
		//una especie de "magia" que va a realizar Dagger Hilt por nosotros gracias a las anotaciones
		//va a proveer las clases que necesite...
		@Provides
		fun provideTaskDao(tasksManageDatabase: TasksManageDatabase): TaskDao {
			//Por eso en TasksManageDatabase estaba esta función abstract fun taskDao():TaskDao
			//para que esto automáticamente me devuelva el DAO (objeto de tipo TaskDao)
			return tasksManageDatabase.taskDao()
		}

		@Provides
		@Singleton
		fun provideTasksManageDatabase(@ApplicationContext appContext: Context): TasksManageDatabase {
			//Aquí realmente es dónde estamos CREANDO la base de datos...
			return Room.databaseBuilder(appContext, TasksManageDatabase::class.java, "TaskDatabase").build()
		}
	}
    ```

	4.4 Preparación del repositorio.
	
	El ***repositorio*** va a ser la clase que va a realizar todas las consultas a la base de datos en nuestro caso. Es la parte más externa de la capa o el módulo de data.
	
	Nuestros ***casos de usos*** le van a pedir al repositorio que hagan las acciones necesarias que necesiten. Y sería el repositorio el que llamaría a lo que necesite de dentro del módulo data para obtener la información o realizar la acción que se le ha solicitado.
	
	Creamos en la carpeta data un fichero `TaskRepository` que será una clase. Debe ser también un ***Singleton*** y estará inyectado por Dagger Hilt.

    ```
	@Singleton
	class TaskRepository @Inject constructor(private val taskDao: TaskDao) {
		//Podríamos haber creado directamente una lista de TaskEntity de la siguiente forma:
		//val tasks: Flow<List<TaskModel>> = taskDao.getTasks()
		//Pero a nivel de arquitectura no es una buena práctica por el acoplamiento de capas.
		//Estamos en data, y ni dominio ni ui deberían conocer que existe un objeto TaskEntity...
		//Para desarrollarlo correctamente, vamos a generar una lista de TaskModel y mapearemos
		//los items del TaskEntity (data) al TaskModel (modelo de la ui)
		//Nosotros vamos a mantener el mismo modelo (TaskModel) para la capa de dominio y ui,
		//pero para la capa de data el modelo es diferente (TaskEntity).
		//Un mapper es cuando recibes unos datos y los devuelves transformados para cada una de las capas.
		//El método map es cómo un forEach, pero me va a devolver una lista de cada item
		//con la transformación que le hagamos mediante la expresión lambda.
		val tasks: Flow<List<TaskModel>> = taskDao.getTasks().map { items -> items.map { TaskModel(it.id, it.task, it.selected) } }
	}
    ```
    
	4.5. Capa de dominio: ***Casos de uso***.
	
	Estos casos de uso van a ser muy simples, pero nos vienen bien para practicar y entenderlos.
	
	Nuestro primer caso de uso va a solicitar una lista de las tareas que estén almacenadas en la base de datos en forma de `Flow` con una lista de `TaskModel`... ***realmente en los casos de uso no sabemos cómo, ni de dónde se va buscar la información, eso es cosa de la capa data, simplemente se lo pedimos al repositorio***.
	
	Creamos en la carpeta domain el fichero `GetTasksUseCase`, que será una clase con el siguiente código:

    ```
	/**
	 * Caso de uso para recuperar las tareas
	 *
	 * Para acceder al data vamos a necesitar el repositorio, ya que es nuestra puerta de entrada al data.
	 * Gracias a Dagger Hilt lo vamos a inyectar en el constructor.
	 */
	class GetTasksUseCase @Inject constructor(private val taskRepository: TaskRepository) {
		operator fun invoke(): Flow<List<TaskModel>> = taskRepository.tasks
	}
    ```
    
	En la misma carpeta, creamos un caso de uso para agregar una tarea. Se llamará AddTaskUseCase:

    ```
	/**
	 * Caso de uso para añadir una tarea
	 */
	class AddTaskUseCase @Inject constructor(private val taskRepository: TaskRepository) {
		suspend operator fun invoke(taskModel: TaskModel) {
			taskRepository.add(taskModel)
		}
	}
    ```

5. **Flows (flujos) en Kotlin.**

	En Kotlin, **Flow** es una API para trabajar con secuencias de valores asincrónicas y potencialmente infinitas. Se utiliza para representar secuencias de valores que se pueden producir y consumir de manera asíncrona.
	
	Básicamente un Flow es cómo un LiveData mejorado que nos permite mandar datos de manera continua. Cuando hacemos una corutina vamos a saber de manera continua cuanto le queda en todo momento... conseguimos con Flow una fuente de continua información o actualización de la información.
	
	En materia de corrutinas, un flujo es un tipo que puede emitir varios valores de manera secuencial, en lugar de suspender funciones que muestran solo un valor único. 
	
	Un flujo se puede usar, por ejemplo, para recibir actualizaciones en vivo de una base de datos.

	Los flujos se compilan sobre las corrutinas y pueden proporcionar varios valores. Un flujo es conceptualmente una transmisión de datos que se puede computar de forma asíncrona.
	
	Para más información: [Flujos de Kotlin en Android](https://developer.android.com/kotlin/flow?hl=es-419)
	
	**El flujo funciona básicamente con las siguientes entidades:**
	
	* ***Productor***, que es el que crea el flujo y en nuestro caso será el ```repositorio```, que es el que está leyendo siempre de la base de datos.
	* ***Intermediario*** (opcional), que en nuestra app será el caso de uso.
	* ***Consumidor***, que es el que consume los valores del flujo y en nuestro caso será la ```UI```... son datos de un listado y queremos que la interfaz de usuario vaya pintando esos datos que va consumiendo.
	
	En nuestra aplicación realmente nosotros estamos siempre devolviendo un flujo, porque nos lo proporciona Room. Pero en la documentación de "Flujos de Kotlin en Android" podéis observar un código de ejemplo de cómo se crearía un flujo:
	
	```
	class NewsRemoteDataSource(
		private val newsApi: NewsApi,
		private val refreshIntervalMs: Long = 5000
	) {
		val latestNews: Flow<List<ArticleHeadline>> = flow {
			while(true) {
				val latestNews = newsApi.fetchLatestNews()
				emit(latestNews) // Emits the result of the request to the flow
				delay(refreshIntervalMs) // Suspends the coroutine for some time
			}
		}
	}

	// Interface that provides a way to make network requests with suspend functions
	interface NewsApi {
		suspend fun fetchLatestNews(): List<ArticleHeadline>
	}
	```
	
	La explicación del código anterior sería la siguiente:
	
	* `NewsRemoteDataSource`: Es una clase que actúa como fuente remota de noticias. Recibe una instancia de NewsApi y un intervalo de actualización (refreshIntervalMs) como parámetros.

	* `latestNews`: Es una propiedad de solo lectura de tipo `Flow<List<ArticleHeadline>>`. Representa la secuencia de noticias más recientes que se actualiza periódicamente.

	* `flow { ... }`: Esto define un constructor de flujo. El bloque de código dentro de las llaves define la lógica para producir elementos en el flujo.

	* `while (true)`: Es un bucle infinito que se ejecuta continuamente para obtener noticias y actualizar el flujo.

	* val `latestNews = newsApi.fetchLatestNews()`: Llama a la función suspendida fetchLatestNews de la interfaz NewsApi para obtener la lista más reciente de titulares de noticias.

	* `emit(latestNews)`: Emite la lista de titulares de noticias al flujo, haciendo que esté disponible para ser consumida por cualquier suscriptor del flujo.

	* `delay(refreshIntervalMs)`: Suspende la ejecución de la coroutine durante el tiempo especificado en refreshIntervalMs. Esto establece un intervalo entre las actualizaciones de noticias.

	En resumen, este código utiliza `Flow` para crear una secuencia de noticias que se actualiza periódicamente. Cada vez que se actualiza, la lista más reciente de titulares de noticias se emite al flujo, y luego el hilo se suspende durante un tiempo especificado antes de la próxima actualización.
	
6. **Tipos de Flow - StateFlow**.

    Hay varios tipos de Flow. Tenemos los Flow normales, pero también existen los `StateFlow` y `SharedFlow`.
	
	Aquí tenéis un enlace a la documentación de Android dónde se explican de forma detallada: [StateFlow y SharedFlow](https://developer.android.com/kotlin/flow/stateflow-and-sharedflow?hl=es-419)

	A nosotros los que nos van a interesar para implementar en nuestro proyecto son los ***`StateFlow`***.
	
	`StateFlow` es un flujo observable contenedor de estados que emite actualizaciones de estado actuales y nuevas a sus recopiladores. El valor de estado actual también se puede leer a través de su propiedad value. Para actualizar el estado y enviarlo al flujo, asigna un nuevo valor a la propiedad value de la clase MutableStateFlow.

	En Android, StateFlow es una excelente opción para clases que necesitan mantener un estado observable que muta.
	
	Veremos a partir de ahora que para mantener los estados de la pantalla necesitamos empezar a trabajar con StateFlow. Para mantener una pantalla de forma correcta, la pantalla necesita ```estados```. Los estados se gestionarán a través de un StateFlow.
	
	***Por ejemplo, nuestra pantalla de gestión o manejo de las tareas puede tener 3 estados:***
	
	- Un estado de ***`loading`*** que se muestra mientras se están cargando los datos.
	- Un estado con datos que los pinta en la UI (***`Success`***).
    - Un estado de error (***`Error`***).	
	
	***A cada estado veremos que podemos proporcionarle un Screen diferente***. Pero para manejar los estados necesitamos trabajar con StateFlow.
	
7. **Flows - Preparando el StateFlow.**

	7.1. Para empezar necesitamos estados de la UI. 
	
	Nos situamos en la carpeta `ui` y creamos una interfaz con el nombre **`TaskUiState`**. Será una `sealed interface` que contendrá los estados de la pantalla. 
	
	Los estados que no reciban datos los vamos a crear cómo `object` y los que si cómo `data class`.

    ```
	/**
	 * Estados de la pantalla
	 */
	sealed interface TaskUiState {
		//Si no recibes datos... usamos object
		object Loading: TaskUiState
		data class Error(val throwable: Throwable): TaskUiState
		//La lista debe ser de elementos de tipo TaskModel porque estamos en la capa de UI.
		//Recordad que TaskEntity solo va a ser accesible desde la capa de data y domain.
		data class Success(val tasks:List<TaskModel>) : TaskUiState
	}
	```
    
	* `sealed interface TaskUiState`: Define una interfaz sellada llamada `TaskUiState`. Es sellada porque todos los subtipos posibles de esta interfaz deben estar declarados en el mismo archivo. Esta interfaz se utiliza para representar los diferentes estados que la interfaz de usuario de la tarea puede tener.

	* `object Loading: TaskUiState`: Representa el estado de carga. Utiliza un objeto *(object)* llamado `Loading` para representar este estado. El objeto Loading es único y no tiene datos asociados.

	* `data class Error(val throwable: Throwable): TaskUiState`: Representa el estado de error. Utiliza una clase de datos *(data class)* llamada `Error` para representar este estado. Tiene un parámetro llamado throwable que es de tipo Throwable, y este parámetro se utiliza para almacenar información sobre el error.

	* `data class Success(val tasks: List<TaskModel>): TaskUiState`: Representa el estado de éxito. Utiliza una clase de datos (data class) llamada `Success` para representar este estado. Tiene un parámetro llamado tasks que es de tipo `List<TaskModel>`, y este parámetro se utiliza para almacenar la lista de tareas exitosamente obtenidas.

	***En resumen***, esta interfaz sellada **`TaskUiState`** define tres estados posibles para la interfaz de usuario de la tarea: carga (**`Loading`**), error (**`Error`**), y éxito (**`Success`**). Cada estado tiene su propia estructura de datos asociada para llevar información específica dependiendo del estado.

	7.2. Modificaciones en TasksViewModel para crear el flujo completo con persistencia en nuestra base de datos.

	Para poder utilizar las llamadas a Success, Error y Loading sin problemas podéis importar lo siguiente en el ViewModel:
	
	```
	import com.dam23_24.ejemploroom.addtasks.ui.TaskUiState.*
	```
	
	Antes de nada, debemos inyectar los casos de uso que hemos creado hasta ahora en el ViewModel, porque los vamos a utilizar:
	
	```
	//El parámetro getTasksUseCase del constructor se inyecta sin private val porque no nos hace falta 
	// ya que lo vamos a utilizar directamente en la variable uiState que gestionará los estados de la ui.
	@HiltViewModel
	class TasksViewModel @Inject constructor(
		private val addTaskUseCase: AddTaskUseCase,
		getTasksUseCase: GetTasksUseCase
	): ViewModel() {
	```
	
	Añadimos la variable **`uiState`**, de tipo `StateFlow`, que va a controlar y gestionar los estados de la ui de nuestra única pantalla:

	```
    //El caso de uso getTasksUseCase() nos devuelve el Flow continuo y cada vez que actualice
    //los datos va a pasarlo a Success (ver data class en TaskUiState).
    //Si por algún motivo falla y existe algún error, lo vamos a capturar y enviar al estado Error
    //con el parámetro de la excepción que ha generado.
    //El último modificador hará que cuando mi app o la pantalla esté en segundo plano hasta que no
    //pasen 5 segundos no bloqueará o cancelará el Flow (por defecto es 0)
    //Por ejemplo nuestra app pasará a segundo plano si nos llaman, o si desplegamos el menú superior
    //para ver una notificación o un whatsapp, etc.
    //Con stateIn, en el último argumento, también estamos asignando el estado inicial a Loading.
    val uiState: StateFlow<TaskUiState> = getTasksUseCase().map(::Success)
        .catch { Error(it) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), Loading)
	```
	
	**Con la variable `uiState` vamos a estar recuperando las tareas que existen en la base de datos continuamente**. Pero para poder obtener las tareas, previamente debemos añadirlas.
	
	Lo siguiente será lanzar con `viewModelScope` el caso de uso para añadir una tarea en nuestra función `onTaskAdded()` del ViewModel. De esta forma, nuestro Flow hará que al insertar la nueva tarea en la base de datos, cómo el flujo es continuo, enviará directamente a Success la nueva tarea para que se pinte por la ui.
	
	***Con esto ya tendríamos un flujo completo.***
	
	```	
	fun onTaskCreated() {
        onDialogClose()

		//Un viewModelScope es una corutina.
        viewModelScope.launch {
            addTaskUseCase(TaskModel(task = _myTaskText.value ?: ""))
        }

        _myTaskText.value = ""
    }
	```
	
	* **`viewModelScope`** es un alcance *(scope)* de `Coroutine` que está asociado con un `ViewModel` en Android cuando se utiliza la arquitectura de `Android Jetpack` y el componente `ViewModel`. Es una instancia de `CoroutineScope` que se gestiona automáticamente en relación con el ciclo de vida del ViewModel. Esto significa que las coroutinas lanzadas en viewModelScope se cancelarán automáticamente cuando el ViewModel sea desvinculado o destruido, evitando posibles fugas de memoria.
	
	* **`viewModelScope.launch { ... }`** crea una nueva corutina en el viewModelScope. Dentro de esta corutina, se llama a `addTaskUseCase` pasando un nuevo objeto `TaskModel` como argumento. Este launch ejecutará la corutina en el hilo principal y estará vinculada al ciclo de vida del ViewModel.
	
	***En resumen***, viewModelScope se utiliza para lanzar coroutinas asociadas con el ciclo de vida de un ViewModel. Esto asegura que las coroutinas se cancelen automáticamente cuando el ViewModel sea desvinculado o destruido, evitando problemas de fugas de memoria y permitiendo una gestión más segura de las operaciones asincrónicas en el contexto del ciclo de vida de un componente ViewModel en Android.

	7.3. Conectar StateFlow con Screen.

	Cómo ya vamos a usar la información de la base de datos, podemos eliminar o comentar inicialmente el siguiente código del ViewModel para sustituirlo por 
	
	```
	//TODO: Código a eliminar. 
	//Utilizamos mutableStateListOf porque se lleva mejor con LazyColumn a la hora
    //de refrescar la información en la vista...
    //private val _tasks = mutableStateListOf<TaskModel>()
    //val tasks: List<TaskModel> = _tasks
	```

	```
	fun onTaskCreated() {
        ...
		//TODO: Código a eliminar. 
        //Log.i("dam2", _myTaskText.value ?: "")
        //_tasks.add(TaskModel(task = _myTaskText.value ?: ""))
        ...
    }
	```

	Después de hacer esto, el IDE mostrará varios errores que debemos ir solucionando y actualizando.
	
	En el mismo ViewModel debemos comentar el código que actualiza el check de las tareas y las elimina:
	
	```
    fun onItemRemove(taskModel: TaskModel) {
        //TODO: Código a eliminar. Falta desarrollar borrar tarea con un caso de uso y lanzarlo como corutina.
		//val task = _tasks.find { it.id == taskModel.id }
        //_tasks.remove(task)
    }
	```

	```
    fun onCheckBoxSelected(taskModel: TaskModel) {
        //TODO: Código a eliminar. Falta desarrollar actualizar tarea con un caso de uso y lanzarlo como corutina.
		//val index = _tasks.indexOf(taskModel)
        _tasks[index] = _tasks[index].let { it.copy(selected = !it.selected) }
    }
	```

	Abrimos `TaskScreen` para solucionar los errores que me aparecen.

	Lo primero será eliminar la lista de tareas que manteníamos

    ```
	fun TasksList(tasksViewModel: TasksViewModel) {
		//Código a eliminar. Ya vamos a recibir los datos del Flow y no nos hace falta esta lista.
		//val myTasks: List<TaskModel> = tasksViewModel.tasks
		...
	}
	```
    
	Pero debemos también realizar unos cambios en nuestra función Composable principal *(TasksScreen)* para que nuestra ui se gestione con los estados de la pantalla que hemos definido previamente. 
	
	Primero debemos crear un ciclo de vida de la Screen:
	
	```
	val lifecycle = LocalLifecycleOwner.current.lifecycle
	```

	Después una variable uiState utilizando `produceState` de la biblioteca de `Kotlin State` para producir un estado *(TaskUiState)* que se puede observar desde la interfaz de usuario:

	``` 
	val uiState by produceState<TaskUiState>(
		initialValue = TaskUiState.Loading,
		key1 = lifecycle,
		key2 = tasksViewModel
	){
		lifecycle.repeatOnLifecycle(state = Lifecycle.State.STARTED) {
			tasksViewModel.uiState.collect{ value = it }
		}
	}
	```

	* **`val uiState by produceState<TaskUiState>(...)`**: Declara una propiedad llamada ***uiState*** que se deriva de *produceState*. produceState es una función de la biblioteca State de Kotlin que permite la creación de estados reactivos que pueden ser observados desde la interfaz de usuario.

	* **`initialValue = TaskUiState.Loading`**: Se establece el valor inicial del estado en TaskUiState.Loading. Esto es lo que se emitirá inicialmente antes de que se inicie la observación.

	* **`key1 = lifecycle, key2 = tasksViewModel`**: Se especifican claves para la propiedad produceState. Esto significa que si cualquiera de estas claves cambia, se invalida el estado y se vuelve a producir. En este caso, se utiliza el ciclo de vida *(lifecycle)* y el *tasksViewModel* como claves.

	* **`lifecycle.repeatOnLifecycle(state = Lifecycle.State.STARTED) { ... }`**: Utiliza la extensión repeatOnLifecycle del ciclo de vida (lifecycle). Esto garantiza que el bloque de código dentro del bloque repeatOnLifecycle solo se ejecutará cuando el estado del ciclo de vida sea STARTED. Esto evita posibles fugas de memoria al observar el estado después de que la actividad o fragmento ya no está activo.

	* **`tasksViewModel.uiState.collect { value = it }`**: Dentro del bloque repeatOnLifecycle, se utiliza collect para observar el flujo uiState del tasksViewModel. Cada vez que hay un nuevo valor en el flujo, se asigna ese valor al estado uiState de la propiedad produceState. Este valor se propagará automáticamente a cualquier observador de uiState en la interfaz de usuario.

	En resumen, este código establece y actualiza el estado `uiState` basado en el flujo **`uiState del tasksViewModel`**, y garantiza que estas actualizaciones solo ocurran cuando la actividad o fragmento esté en el estado STARTED. Es decir, nos va a crear un estado permanente que podemos leer en la ui, ya que estará suscrito al estado del ViewModel que hemos definido anteriormente.

	Por último, dependiendo del estado en el que nos encontremos, podremos pintar una pantalla u otra:

	```
	when (uiState) {
		is TaskUiState.Error -> {  }
		is TaskUiState.Loading -> {
			Box(modifier = Modifier.fillMaxSize()) {
				CircularProgressIndicator(
					modifier = Modifier
						.size(150.dp)
						.align(Alignment.Center)
				)
			}
		}
		is TaskUiState.Success -> {
			Box(modifier = Modifier.fillMaxSize()) {
				AddTasksDialog(
					show = showDialog,
					myTaskText = myTaskText,
					onDismiss = { tasksViewModel.onDialogClose() },
					onTaskAdded = { tasksViewModel.onTaskCreated() },
					onTaskTextChanged = { tasksViewModel.onTaskTextChanged(it) }
				)
				FabDialog(
					Modifier.align(Alignment.BottomEnd),
					onNewTask = { tasksViewModel.onShowDialogClick() })
				TasksList((uiState as TaskUiState.Success).tasks, tasksViewModel)
			}
		}
	}
	```

	Si os fijáis, en la llamada a la función TasksList le vamos a pasar ya la lista de tipo TaskModel (que antes habíamos comentado porque vamos a utilizar la que me proporciona el flujo del estado). Nuestra función quedaría como sigue:
	
	```
	@Composable
	fun TasksList(tasks: List<TaskModel>, tasksViewModel: TasksViewModel) {
		LazyColumn {
			items(tasks, key = { it.id }) { task ->
				ItemTask(
					task,
					onTaskRemove = { tasksViewModel.onItemRemove(it) },
					onTaskCheckChanged = { tasksViewModel.onCheckBoxSelected(it) }
				)
			}
		}
	}
	```

	### TAREA A REALIZAR:

	Ya tendríamos todo corregido y solo nos faltaría eliminar los comentarios marcados como "TODO: Código a eliminar" y añadir la funcionalidad de borrar una tarea y actualizarla de la misma manera que hemos hecho con listar las tareas...
	
	***Pero esta tarea os la dejo a vosotros***
	
	Debéis crear los casos de usos UpdateTaskUseCase y DeleteTaskUseCase, crear las funciones correspondientes en el TaskRepository y las consultas necesarias en TaskDao (con las anotaciones correspondientes @Update y @Delete)
	
	Por último, en el TaskRepository podemos hacer una modificación que os va a enseñar un nuevo concepto de las funciones en Kotlin que quizás no conocéis todos.
	
	Os doy una función de extensión sobre TaskModel que se llama toData() y retorna un TaskEntity con los propios datos del TaskModel... vosotros debéis intentar aplicarla como parámetro de las 3 funciones addTask, updateTask y deleteTask que se llaman desde el taskDao y deben pasar por argumento un TaskEntity con la info del TaskModel que recibe la función suspendida.
	
	Una función de extensión agrega un método a una clase sin tener que crear un nuevo tipo, heredar de la clase origen y añadir un nuevo método.
	
	En este caso podéis ubicarla fuera de la clase, pero en el mismo fichero TaskRepository.

	```
	fun TaskModel.toData(): TaskEntity {
		return TaskEntity(this.id, this.task, this.selected)
	}
	```

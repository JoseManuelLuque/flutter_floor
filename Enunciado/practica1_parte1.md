# Práctica 1 - Lista de Tareas - PARTE 1

## Desarrollo de una app móvil en Kotlin (Android Studio) para gestionar una lista de tareas

### PARTE 1:

1. **Introducción y creación del proyecto.**

	Primero vamos a preparar el proyecto y crear la arquitectura básica MVVM del proyecto.

	1.1. Crear un proyecto en Android Studio con la plantilla `Empty Activity` de JetPack Compose.

	1.2. Crear un package con el nombre de la feature: `addtasks` y dentro sus carpetas básicas: `data`, `domain` y `ui`.
	
	1.3. Crear el fichero de Kotlin con la vista, que se llamará por ejemplo `TasksScreen`, dentro de la carpeta `ui` del paquete `addtasks`. Este fichero contendrá la función Composable básica principal con el mismo nombre que el fichero y el resto de funciones Composable que necesitemos para la creación de nuestro diseño final.
	
	1.4. Realizar la llamada de la función Composable principal `TasksScreen` en `MainActivity`.
	
	1.5. Crear un fichero "Application" que nos servirá posteriormente para la "inyección de dependencias con Dagger Hilt" y "Room".

   Para ello, en la misma ubicación del `MainActivity`, creamos una clase de Kotlin con el nombre de nuestra aplicación, en este caso la vamos a llamar `TasksManageApp` y su contenido será el siguiente:  

	```
	class TasksManageApp : Application()
	```
 
	1.6. Para que funcione correctamente, tenemos que realizar cambios en el fichero `AndroidManifest.xml` e introducir el atributo de application `android:name` para indicarle cuál es mi clase Application:

    ```
	<application
		...
		android:name=".TasksManageApp"
		...>
		<activity
			...>
		</activity>
	</application>
	```
	
	1.7. Por último, para terminar de crearnos nuestra arquitectura básica, vamos a crear el ViewModel. También lo ubicaremos en la carpeta `ui` de `addtasks` con el nombre `TasksViewModel` (class) que hereda de ViewModel:

    ```
	class TasksViewModel : ViewModel() {
	}
    ```
    
3. **Implementar la inyección de dependencias con Dagger Hilt.**

	2.1. En el gradle principal, `build.gradle.kts (Project)`, debemos insertar un nuevo plugin:

    ```    
	plugins {
		...

		//Dagger Hilt
		id("com.google.dagger.hilt.android") version "2.44" apply false
	}
    ```

	2.2. En el gradle de la aplicación, build.gradle.kts (Module), debemos insertar las siguientes librerías:

   ```
	plugins {
		...

		//Dagger Hilt
		kotlin("kapt")
		id("com.google.dagger.hilt.android")
	}

	dependencies {
		...

		//Dagger Hilt
		implementation("com.google.dagger:hilt-android:2.44")
		kapt("com.google.dagger:hilt-android-compiler:2.44")
	}

	//Dagger Hilt - Allow references to generated code
	kapt {
		correctErrorTypes = true
	}
    ```

	2.3. Ahora **SINCRONIZAMOS** el Gradle que hemos modificado ***(Sync Now)***.
	
	2.4. Una vez sincronizado, ya podemos comenzar a incluir las anotaciones de **Dagger Hilt** que necesitamos.

    Primero actualizamos `TasksManageApp`:

    ```
	@HiltAndroidApp
	class TasksManageApp: Application()
    ```
    
	2.5. En el fichero `MainActivity` incluimos la anotación ***@AndroidEntryPoint*** y crearemos la variable que pasaremos a nuestra Screen con el ViewModel de la misma:

    ```
	@AndroidEntryPoint
	class MainActivity : ComponentActivity() {

		private val tasksViewModel: TasksViewModel by viewModels()

		override fun onCreate(savedInstanceState: Bundle?) {
			super.onCreate(savedInstanceState)
			setContent {
				EjemploRoomTheme {
					Surface(
						modifier = Modifier.fillMaxSize(),
						color = MaterialTheme.colorScheme.background
					) {
						TasksScreen(tasksViewModel)
					}
				}
			}
		}
	}
    ```
    
	2.6. Por último, vamos a ir al ViewModel e incluioms la anotación de Dagger Hilt para indicar que se trata de un ViewModel y añadimos a la clase la anotación de la inyección del constructor cómo indica la documentación de Dagger Hilt:

    ```
	@HiltViewModel
	class TasksViewModel @Inject constructor(): ViewModel() {
	}
    ```

3. **Diálogo creador de las tareas.**

	3.1. Lo primero que vamos a hacer es introducir las dependencias necesarias para trabajar con ***LiveData*** en `build.gradle.kts (Module)` y volvemos a sincronizar ***(Sync Now)***:

    ```
	dependencies {
		...
		//LiveData
		implementation("androidx.compose.runtime:runtime-livedata:1.5.4")
	}	
    ```

	3.2. Creamos en `TasksScreen` la función Composable que va a contener el botón para añadir una tarea.

    ```
	@Composable
	fun TasksScreen(tasksViewModel: TasksViewModel) {
		//Para poder alinear el botón abajo a la derecha del contenedor, le pasamos el modifier con la alineación desde su contenedor...
		Box(modifier = Modifier.fillMaxSize()) {
			FabDialog(
				Modifier.align(Alignment.BottomEnd))
		}
	}
    ```

    ```
	@Composable
	fun FabDialog(
		modifier: Modifier
	) {
		FloatingActionButton(
			onClick = {
				//Mostrar diálogo para añadir una tarea
			}, modifier = modifier.padding(16.dp)
		) {
			Icon(Icons.Filled.Add, contentDescription = "")
		}
	}
    ```
    
	3.3. Creamos ahora la función que contendrá el diálogo para añadir una tarea... `AddTasksDialog`:
	
	* En TasksViewModel:

        ```
	    private val _showDialog = MutableLiveData<Boolean>()
		val showDialog: LiveData<Boolean> = _showDialog

		private val _myTaskText = MutableLiveData<String>()
		val myTaskText: LiveData<String> = _myTaskText
		
		fun onDialogClose() {
			_showDialog.value = false
		}
		
		fun onTaskCreated() {
			onDialogClose()
			Log.i("dam2", _myTaskText.value ?: "")
			_myTaskText.value = ""
		}
		
		fun onShowDialogClick() {
			_showDialog.value = true
		}

		fun onTaskTextChanged(taskText: String) {
			_myTaskText.value = taskText
		}
        ```

	* En TasksScreen:

        ```
		@Composable
		fun TasksScreen(tasksViewModel: TasksViewModel) {
			val showDialog: Boolean by tasksViewModel.showDialog.observeAsState(false)
			val myTaskText: String by tasksViewModel.myTaskText.observeAsState("")

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
				TasksList(tasksViewModel)
			}
		}
        ```

        ```
		@OptIn(ExperimentalMaterial3Api::class)
		@Composable
		fun AddTasksDialog(
			show: Boolean,
			myTaskText: String,
			onDismiss: () -> Unit,
			onTaskAdded: () -> Unit,
			onTaskTextChanged: (String) -> Unit
		) {
			if (show) {
				Dialog(onDismissRequest = { onDismiss() }) {
					Column(
						Modifier
							.fillMaxWidth()
							.background(Color.White)
							.padding(16.dp)
					) {
						Text(
							text = "Añade tu tarea",
							fontSize = 18.sp,
							modifier = Modifier.align(Alignment.CenterHorizontally),
							fontWeight = FontWeight.Bold
						)
						Spacer(modifier = Modifier.size(16.dp))
						TextField(
							value = myTaskText,
							onValueChange = { onTaskTextChanged(it) },
							singleLine = true,
							maxLines = 1
						)
						Spacer(modifier = Modifier.size(16.dp))
						Button(
							onClick = {
								onTaskAdded()
							},
							modifier = Modifier.fillMaxWidth()
						) {
							Text(text = "Añadir tarea")
						}
					}
				}
			}
		}
        ```

   3.4. Ejecutar la aplicación y probar su funcionamiento con lo que hemos desarrollado hasta ahora:

   * Debe mostrarse una pantalla sin tareas y con un único botón en la zona inferior derecha.
   * Al pulsar sobre el botón, debe mostrarse una ventana de diálogo para añadir una tarea.
   * Cuando pulsamos el botón "Añadir tarea" debemos comprobar en el Log que se está escribiendo el texto que hemos escrito cómo descripción de la misma.
   * También debe cerrarse la ventana de diálogo, tanto al pulsar fuera del diálogo *(onDismiss)*, cómo al añadir la tarea *(después de pulsar el botón "Añadir tarea")* 

   3.5. Después de comprobar que todo está bien implementado, vamos a crear el modelo de datos para poder crear, editar, eliminar y mostrar las tareas. También necesitaremos crear las funciones Composable que van a mostrar la lista de tareas.

   Los modelos de la ***UI*** los incluiremos en una nueva carpeta que crearemos en `addtasks/ui/model` *(nuevo package)* y le daremos el nombre **`TaskModel`**, que será una *data class*.

   En **`TaskModel`** crearemos el modelo de datos de la información que se almacenará de cada tarea:

    ```
	//Nuestro modelo de datos...
	//El valor del id por defecto lo vamos a calcular con el momento en el que lo creamos, es decir, el tiempo en milisegundos.
	//El valor de la casilla de verificación por defecto debería ser siempre falso cuando creamos la tarea.
	data class TaskModel(
		val id: Long = System.currentTimeMillis(),
		val task: String,
		var selected: Boolean = false
	)
    ```
    
    En **`TaskScreen`** creamos las funciones Composable encargadas de listar las tareas:

    ```
	@Composable
	fun TasksList(tasksViewModel: TasksViewModel) {
		val myTasks: List<TaskModel> = tasksViewModel.tasks

		LazyColumn {
			//El parámetro opcional key ayuda a optimizar el LazyColumn
			//Al indicarle que la clave es el id va a ser capaz de identificar cada tarea sin problemas
			items(myTasks, key = { it.id }) { task ->
				ItemTask(
					task,
					onTaskRemove = { tasksViewModel.onItemRemove(it) },
					onTaskCheckChanged = { tasksViewModel.onCheckBoxSelected(it) }
				)
			}
		}
	}
    ```

    ```
	@Composable
	fun ItemTask (
		taskModel: TaskModel,
		onTaskRemove: (TaskModel) -> Unit,
		onTaskCheckChanged: (TaskModel) -> Unit
	) {
		Card(
			//pointerInput es una función se utiliza para configurar la entrada de puntero (input)
			//para el componente visual al que se le aplica... la detección de gestos de entrada táctil
			//En nuestro caso queremos eliminar una tarea con el gesto de pulsación larga (onLongPress)
			//sobre la tarea, por lo tanto el componente visual dónde aplicar el modificador debe ser el Card.
			//En la expresión lambda no podemos utilizar it como parámetro de la llamada a onTaskRemove(it)
			//it es el Offset y nosotros necesitamos pasarle el taskModel que debe eliminarse...
			Modifier
				.fillMaxWidth()
				.padding(horizontal = 16.dp, vertical = 8.dp)
				.pointerInput(Unit) {
					detectTapGestures(onLongPress = {
						onTaskRemove(taskModel)
					})
				},
			elevation = CardDefaults.cardElevation(defaultElevation = 8.dp)
		) {
			Row(
				Modifier
					.fillMaxWidth(),
				verticalAlignment = Alignment.CenterVertically
			) {
				Text(
					text = taskModel.task,
					modifier = Modifier
						.padding(horizontal = 4.dp)
						.weight(1f)
				)
				Checkbox(
					checked = taskModel.selected,
					onCheckedChange = { onTaskCheckChanged(taskModel) }
				)
			}
		}
	}
    ```
    
	En **`TasksViewModel`** creamos una estructura de datos para almacenar la lista de tareas *(_tasks)*, actualizamos la función que agrega una nueva tarea para que la añada a la lista y añadimos las funciones que nos quedaban por desarrollar para eliminar una tarea y actualizar la casilla de verificación de una tarea:

    ```
	//Los LiveData no van bien con los listados que se tienen que ir actualizando...
    //Para solucionarlo, podemos utilizar un mutableStateListOf porque se lleva mejor con LazyColumn a la hora de refrescar la información en la vista...
    private val _tasks = mutableStateListOf<TaskModel>()
    val tasks: List<TaskModel> = _tasks
	```
	
	```
	//Actualizamos la función para crear la tarea en la lista anterior
	//Comentamos el mensaje al log que hemos realizado inicialmente y añadimos una nueva tarea a la lista _tasks
	fun onTaskCreated() {
        onDialogClose()
        //Log.i("dam2", _myTaskText.value ?: "")
        _tasks.add(TaskModel(task = _myTaskText.value ?: ""))
        _myTaskText.value = ""
    }
    ```

    ```
    fun onItemRemove(taskModel: TaskModel) {
        //No podemos usar directamente _tasks.remove(taskModel) porque no es posible por el uso de let con copy para modificar el checkbox...
        //Para hacerlo correctamente, debemos previamente buscar la tarea en la lista por el id y después eliminarla
        val task = _tasks.find { it.id == taskModel.id }
        _tasks.remove(task)
    }
    ```

    ```
    fun onCheckBoxSelected(taskModel: TaskModel) {
        val index = _tasks.indexOf(taskModel)

        //Si se modifica directamente _tasks[index].selected = true no se recompone el item en el LazyColumn
        //Esto nos ha pasado ya en el proyecto BlackJack... ¿¿os acordáis?? :-(
        //Y es que la vista no se entera que debe recomponerse, aunque realmente si se ha modificado el valor en el item
        //Para solucionarlo y que se recomponga sin problemas en la vista, lo hacemos con un let...
        
        //El método let toma como parámetro el objeto y devuelve el resultado de la expresión lambda
        //En nuestro caso, el objeto que recibe let es de tipo TaskModel, que está en _tasks[index] 
        //(sería el it de la exprexión lambda)
        //El método copy realiza una copia del objeto, pero modificando la propiedad selected a lo contrario
        //El truco está en que no se modifica solo la propiedad selected de tasks[index], 
        //sino que se vuelve a reasignar para que la vista vea que se ha actualizado un item y se recomponga.
        _tasks[index] = _tasks[index].let { it.copy(selected = !it.selected) }
    }
    ```
    
	3.6. ***Para finalizar la parte 1 de la práctica***, realizamos una prueba completa de nuestra app de gestión de tareas, aunque aún sin la conexión a la base de datos con `Room`.

    Debemos comprobar que todo funciona correctamente:

    * Se añaden tareas a la lista _tasks.
    * Se muestran en la pantalla principal de la app.
    * Se puede actualizar la casilla de verificación de cada tarea.
    * Se puede eliminar una tarea al pulsar de manera prolongada sobre ella.

    Pero si cerramos la aplicación y volvemos a abrirla no existe persistencia de datos... esto lo vamos a conseguir con la implementación en el proyecto de `Room` y `Flow`.
	
	***En este punto debemos hacer un commit y push de nuestra rama principal y crearnos otra con el nombre `desarrollo_room`, dónde realizaremos la parte 2 de la práctica.***

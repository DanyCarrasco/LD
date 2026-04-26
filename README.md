## 🃏 Reglas del Truco (resumen estructurado)

---

## 🏆 ¿Cómo gana un jugador?

* Gana quien alcanza **30 puntos**.
* Los puntos se dividen en:

  * 🔹 **Malas**: primeros 15 puntos
  * 🔸 **Buenas**: últimos 15 puntos
* Un jugador entra en **buenas** cuando llega a **15 puntos o más**.

👉 Por lo tanto, **no hace falta preguntar explícitamente** si juegan malas o buenas:
eso se **deduce automáticamente del puntaje actual**.

---

## 👥 Jugadores

* Participan:

  * 🧍‍♂️ Jugador
  * 🧍‍♂️ Oponente
* Se debe registrar quién es **🖐️ mano** (importante en empates).

---

## 🎴 Envido

📌 Se canta en la **primera mano** y **antes del truco**.

### 🧮 Cómo se calcula:

* Dos cartas del mismo palo → sumar valores + **20**
* Figuras (sota, caballo, rey) → valen **0**
* 🟢 Mayor valor gana

---

### 🔁 Flujo del Envido

#### ▶️ Envido

* **Quiero** ✅ → gana: **2 puntos**
* **No quiero** ❌ → gana: **1 punto**

#### ▶️ Envido → Envido

* **Quiero** ✅ → gana: **4 puntos**
* **No quiero** ❌ → gana: **2 puntos**

#### ▶️ Envido → Real Envido

* **Quiero** ✅ → gana: **7 puntos**
* **No quiero** ❌ → gana: **4 puntos**

#### ▶️ Envido → Falta Envido

* **Quiero** ✅:

  * 🔸 En buenas → gana hasta llegar a **30**
  * 🔹 En malas → gana hasta llegar a **15**
* **No quiero** ❌ → gana: **7 puntos**

---

### ▶️ Real Envido directo

* **Quiero** ✅ → gana: **3 puntos**
* **No quiero** ❌ → gana: **1 punto**

#### ↳ Real Envido → Falta Envido

* **Quiero** ✅:

  * 🔸 Buenas → hasta 30
  * 🔹 Malas → hasta 15
* **No quiero** ❌ → gana: **3 puntos**

---

### ▶️ Falta Envido directo

* **Quiero** ✅:

  * 🔸 Buenas → hasta 30
  * 🔹 Malas → hasta 15
* **No quiero** ❌ → gana: **1 punto**

---

### 🚪 En cualquier momento:

* ❌ **Irse al mazo (rendirse)**

---

## 🎯 Truco

📌 Se puede cantar en **cualquier momento**.

### 🔁 Flujo del Truco

#### ▶️ Truco

* **Quiero** ✅ → gana: **2 puntos**
* **No quiero** ❌ → gana: **1 punto**

#### ▶️ Retruco

* **Quiero** ✅ → gana: **3 puntos**
* **No quiero** ❌ → gana: **2 puntos**

#### ▶️ Vale 4

* **Quiero** ✅ → gana: **4 puntos**
* **No quiero** ❌ → gana: **3 puntos**

---

### 🚪 También se puede:

* ❌ **Irse al mazo**

---

## 🃏 Desarrollo de la Ronda

Se juegan hasta **3 manos**:

### 📊 Casos posibles:

* ✅ Gana 1ra y 2da → gana ronda
* ✅ Gana 1ra y empata 2da → gana ronda
* ✅ Gana 1ra, pierde 2da, gana 3ra → gana ronda
* ✅ Gana 1ra, pierde 2da, empata 3ra → gana ronda
* 🤝 Todas empardadas → gana el **🖐️ mano**
* 🤝 Empata 1ra, gana 2da → gana ronda

---

## ⚙️ Reglas importantes de flujo

* 🧠 El sistema debe saber:

  * Puntaje de cada jugador
  * Si están en **malas o buenas**
  * Quién es **mano**
* ❗ Después de un **"quiero"**, se debe permitir:

  * 🃏 Mostrar cartas
  * 🚪 Irse al mazo

---

## 🚫 Flor

* No se juega por defecto
* Se debe **acordar antes de la ronda**

---

## 💡 Nota de implementación (clave para Prolog o lógica)

* El estado del juego podría representarse como:

  * `puntos(Jugador, Puntos)`
  * `estado(buenas | malas)`
  * `mano(Jugador)`
  * `apuesta_actual(envido | truco | ...)`

---

#ifndef NAND_H
#define NAND_H

#include <stdbool.h>
#include <stddef.h>
#include <sys/types.h>
#include <errno.h>
#include <malloc.h>

// Nand struct definition
struct nand {
    struct nand** input_array;
    struct linked_list* output_list;
    unsigned input_array_size;
    unsigned number_of_outputs;
    bool value;
    bool is_evaluated;
    bool is_being_evaluated;
    bool is_a_signal;
    bool* signal_value;
    ssize_t local_path_length;
};

typedef struct nand nand_t;

// Linked list struct definition
struct linked_list {
    nand_t* nand;
    struct linked_list* next;
};

typedef struct linked_list list_t;

// Function freeing whole linked list
void free_linked_list(list_t* start){
    list_t* current = start;
    list_t* next;

    while (current != NULL) {
        next = current->next;
        free(current);
        current = next;
    }
}

// Function deleting output from linked list
void remove_from_list(list_t** start, nand_t* output_to_remove){
    if (start == NULL) return;

    list_t* current = *start;
    list_t* previous = NULL;

    // Going through the list and freeing element with the targeted output
    while (current != NULL) {
        if (current->nand == output_to_remove) {
            if (previous == NULL) { // Output is at the start of the list
                *start = current->next;
            } else {
                previous->next = current->next;
            }
            free(current);
            return;
        }

        previous = current;
        current = current->next;
    }
}

// Function adding gate to the front of the list
int add_to_list(list_t** start, nand_t* nand){
    // Allocating memory for the new node
    list_t* new_node = (list_t *) malloc(sizeof(list_t));

    if (new_node == NULL) {
        return -1; // Memory allocation error
    }

    if (*start == NULL) new_node->next = NULL;
    else new_node->next = *start;

    // Setting new node as the new start of the list
    *start = new_node;
    new_node->nand = nand;
    return 0;
}

// Function creating new nand gate with n inputs
nand_t* nand_new(unsigned n){
    // Allocating memory for a new nand gate
    nand_t* new_nand = (nand_t*) malloc(sizeof(nand_t));

    if (new_nand == NULL) {
        errno = ENOMEM; // Memory allocation error
        return NULL;
    }

    // Allocating memory for input array
    new_nand->input_array = (nand_t**) malloc(n * sizeof(nand_t*));
    new_nand->input_array_size = n;

    if (new_nand->input_array == NULL) {
        free(new_nand);
        errno = ENOMEM; // Memory allocation error
        return NULL;
    }

    // Initializing input array
    for (int i = 0; i < (int) n; i ++) {
        (new_nand->input_array)[i] = NULL;
    }

    //Initializing remaining variables
    new_nand->output_list = NULL;
    new_nand->number_of_outputs = 0;
    new_nand->value = false;
    new_nand->is_evaluated = false;
    new_nand->is_being_evaluated = false;
    new_nand->is_a_signal = false;
    new_nand->local_path_length = -1;
    new_nand->signal_value = NULL;

    return new_nand;
}

// Function deleting nand gate and freeing allocated memory
void nand_delete(nand_t *g){
    if (g == NULL) {
        return; // Nand gate is already a NULL
    }

    // Severing connections to input gates
    for (unsigned i = 0; i < g->input_array_size; i++) {
        if (g->input_array[i] != NULL) {
            nand_t* searched_gate = g->input_array[i];
            if (searched_gate->is_a_signal) {
                // Freeing a bool input signal
                free(searched_gate->input_array);
                free(searched_gate);
            } else {
                // Removing g from input's output list
                remove_from_list(&(searched_gate->output_list), g);
                searched_gate->number_of_outputs = searched_gate->number_of_outputs -1;
            }
        }
    }

    // Severing connections to output gates
    list_t* current = g->output_list;
    while (current != NULL) {
        nand_t* searched_gate = current->nand;
        int temp = 0;
        while (searched_gate->input_array[temp] != g) {
            temp++;
        }
        searched_gate->input_array[temp] = NULL;
        current = current->next;
    }

    // Freeing allocated memory
    free(g->input_array);
    free_linked_list(g->output_list);
    free(g);
}

// Function connecting g_out output to g_in input number k
int nand_connect_nand(nand_t *g_out, nand_t *g_in, unsigned k){
    // Checking whether pointer are empty and k is not out of bounds
    if (g_in == NULL || g_out == NULL || k >= g_in->input_array_size) {
        errno = EINVAL; // Incorrect entry data
        return -1;
    }

    nand_t** input_array = g_in->input_array;

    // Deleting old input if it is a signal and not a gate
    if (input_array[k] != NULL && input_array[k]->is_a_signal) {
        nand_delete(input_array[k]);
        input_array[k] = NULL;
    }

    // Deleting g_in from the old input's output_list
    if (input_array[k] != NULL && !input_array[k]->is_a_signal) {
        input_array[k]->number_of_outputs = input_array[k]->number_of_outputs - 1;
        remove_from_list(&(input_array[k]->output_list), g_in);
    }

    // Setting g_out as g_in's input
    input_array[k] = g_out;

    // Adding g_in to the front of g_out's output list and checking for memory error
    if (add_to_list(&(g_out->output_list), g_in) == -1) {
        errno = ENOMEM; // Memory allocation error
        return -1;
    }

    (g_out->number_of_outputs)++;
    return 0;
}

// Function connecting bool signal s to g's input number k
int nand_connect_signal(bool const *s, nand_t *g, unsigned k){
    // Checking whether pointer are empty
    if (g == NULL || s == NULL) {
        errno = EINVAL; // The pointer is NULL
        return -1;
    }

    // Checking whether k is not out of bounds
    if (k >= g->input_array_size) {
        errno = EINVAL; // Incorrect k value
        return -1;
    }

    nand_t** input_array = g->input_array;

    // Deleting old input if it is a signal and not a gate
    if (input_array[k] != NULL && input_array[k]->is_a_signal) {
        nand_delete(input_array[k]);
        input_array[k] = NULL;

    }

    // Deleting g_in from the old input's output_list
    if (input_array[k] != NULL && !input_array[k]->is_a_signal) {
        input_array[k]->number_of_outputs = input_array[k]->number_of_outputs - 1;
        remove_from_list(&(input_array[k]->output_list), g);
    }

    // Creating new gate to host a signal
    nand_t* new_signal = nand_new(0);

    if (new_signal == NULL) {
        errno = ENOMEM; // Memory allocation error
        return -1;
    }

    // Initializing and assigning signal to input array
    new_signal->is_a_signal = true;
    new_signal->signal_value = (bool*) s;
    input_array[k] = new_signal;

    return 0;
}

// Function evaluating a single gate's output signal, returning critical path's length
ssize_t nand_single_evaluate(list_t** gates_being_evaluated, ssize_t curr_path, nand_t* target){
    if (target->input_array_size == 0) {
        target->is_evaluated = true;
        target->value = false;
        target->local_path_length = 0;
        return 0;
    }

    // setting target's is_being_evaluated tag to true to look out for loops
    target->is_being_evaluated = true;

    bool result = false;
    ssize_t longest_path = curr_path;

    // Checking every input's value
    for (unsigned i = 0; i < target->input_array_size; i++) {
        nand_t* searched_gate = target->input_array[i];

        // Checking whether input is not a NULL
        if (searched_gate == NULL) {
            errno = ECANCELED; // Evaluation failed - input is a NULL
            return -1;
        }

        // Checking whether input is a bool signal
        if (searched_gate->is_a_signal && *(searched_gate->signal_value) == false) {
            result = true;
        }
        else if (!searched_gate->is_a_signal) { // Input is a nand gate
            // Checking whether there is a loop
            if (searched_gate->is_being_evaluated) {
                errno = ECANCELED ; // Evaluation failed - loop detected
                return -1;
            }

            // Evaluating input's value
            ssize_t input_path;
            if (!searched_gate->is_evaluated) {
                input_path = nand_single_evaluate(gates_being_evaluated,
                                                  curr_path,
                                                  searched_gate);
                if (input_path == -1) { searched_gate->is_being_evaluated = false; return -1;} else input_path++;
            } else{
                input_path = searched_gate->local_path_length;
            }

            if (input_path == -1) { searched_gate->is_being_evaluated = false; return -1;} // Failed to evaluate input's value
            if (input_path > longest_path) longest_path = input_path;
            if (searched_gate->value == false) result = true;
        }
    }

    // Setting target's tag to evaluated
    target->is_evaluated = true;
    target->value = result;
    target->local_path_length = longest_path + 1;
    target->is_being_evaluated = false;
    
    return longest_path;
}

// Function setting gate and all the connected gates' is_evaluated tags to false
void clear_evaluation_tags(nand_t* gate){
    if (gate == NULL || !gate->is_evaluated || gate->is_a_signal) return;

    gate->is_evaluated = false;
    gate->is_being_evaluated = false;
    gate->local_path_length = -1;

    for (unsigned i = 0; i < gate->input_array_size; i++) {
        clear_evaluation_tags(gate->input_array[i]);
    }
}

// Function evaluating values of nand gates in the array,
// returning longest critical path's length
ssize_t nand_evaluate(nand_t **g, bool *s, size_t m){
    // Checking whether pointers are empty and m in not out of bounds
    if (g == NULL || s == NULL || (int) m <= 0 ) {
        errno = EINVAL; // The pointer is NULL
        return -1;
    }

    list_t* gates_currently_evaluated = NULL;
    ssize_t longest_path_length = -1;

    // Evaluating all the gates in the array
    for (int i = 0; i < (int) m; i ++) {
        if (g[i] == NULL || (i+1 < (int) m && g[i+1] == NULL)) {
            errno = EINVAL; // The pointer is NULL
            return -1;
        }

        ssize_t path_length = nand_single_evaluate(
                &gates_currently_evaluated,1, g[i]);


        if (path_length == -1) { // Checking whether evaluation failed
            free_linked_list(gates_currently_evaluated);
            return -1;
        }

        if (path_length > longest_path_length) longest_path_length = path_length;
        s[i] = (g[i])->value;
    }

    // setting all is_evaluated tags to false
    for (int i = 0; i < (int) m; i ++) {
        clear_evaluation_tags(g[i]);
    }

    free_linked_list(gates_currently_evaluated);
    return longest_path_length;
}

// Function returning the number of gates connected to g's output
ssize_t nand_fan_out(nand_t const *g){
    // Checking whether pointer are empty
    if (g == NULL) {
        errno = EINVAL; // The pointer is NULL
        return -1;
    }

    return g->number_of_outputs;
}

// Function returning pointer to g's k-th input
void*   nand_input(nand_t const *g, unsigned k){
    // Checking if the input data is correct
    if (g == NULL || k >= g->input_array_size) {
        errno = EINVAL; // Invalid pointer or k's value
        return NULL;
    }

    // Checking if the input signal is not a NULL
    if ((g->input_array)[k] == NULL) {
        errno = 0; // There is no input source
        return NULL;
    }

    // Returning pointer to input's source
    if ((g->input_array)[k]->is_a_signal) return (g->input_array)[k]->signal_value;
    return (g->input_array)[k];
}

// Function returning pointer to g's k-th output
nand_t* nand_output(nand_t const *g, ssize_t k){
    if (g == NULL || k >= g->number_of_outputs) {
        errno = EINVAL; // Invalid pointer or k's value
        return NULL;
    }

    list_t* current = g->output_list;

    for (int i = 0; i < (int) k; i++) {
        current = current->next;
    }

    return current->nand;
}

#endif
